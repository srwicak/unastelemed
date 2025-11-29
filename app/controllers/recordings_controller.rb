class RecordingsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_medical_staff, except: [:show, :chart, :data]
  before_action :set_recording, only: [:show, :chart, :data]

  def index
    # Hanya untuk medical staff
    @recordings = Recording.includes(:patient, :hospital, :user)
                           .order(created_at: :desc)
                           .page(params[:page])
    
    # Filter berdasarkan role
    if current_user.medical_staff
      @recordings = @recordings.where(user_id: current_user.id)
    end
  end

  def show
    unless can_view_recording?(@recording)
      redirect_to root_path, alert: 'Akses ditolak'
      return
    end
  end

  def chart
    unless can_view_recording?(@recording)
      redirect_to root_path, alert: 'Akses ditolak'
      return
    end
    
    @data_points = @recording.biopotential_samples
                             .order(:sequence_number)
                             .limit(10000)
  end

  def data
    unless can_view_recording?(@recording)
      render json: { error: 'Akses ditolak' }, status: :forbidden
      return
    end

    # Use start_time (actual recording start) instead of created_at (database record creation)
    recording_start = @recording.start_time || @recording.created_at
    recording_end = (@recording.end_time || recording_start) + (@recording.duration_seconds || 0).seconds
    
    start_time = params[:start_time] ? Time.zone.parse(params[:start_time]) : recording_start
    end_time = params[:end_time] ? Time.zone.parse(params[:end_time]) : recording_end
    
    # Ensure valid range
    start_time = [start_time, recording_start].max
    end_time = [end_time, recording_end].min
    
    # Calculate total duration and estimated samples
    duration = end_time - start_time
    
    # Target resolution: ~10000 points for the visible range to preserve EKG peaks
    target_points = 10000
    
    batches = @recording.biopotential_batches
                        .by_time_range(start_time, end_time)
                        .ordered
    
    data = []
    
    # We need to stream/process batches to avoid loading everything into memory if possible,
    # but for now we load batches.
    
    total_samples_estimate = batches.sum { |b| b.data['samples']&.size || 0 }
    
    # Calculate skip factor (1 = take all, 2 = take every 2nd, etc.)
    skip = (total_samples_estimate / target_points.to_f).ceil
    skip = [skip, 1].max
    
    Rails.logger.info "Downsampling: #{total_samples_estimate} samples -> target #{target_points} (skip=#{skip})"
    
    # Track cumulative sample count for continuous timeline
    cumulative_samples = 0
    sample_rate = @recording.sample_rate || 500.0
    time_per_sample = 1.0 / sample_rate  # seconds per sample
    
    batches.each do |b|
      samples = b.samples
      next if samples.empty?
      
      count = samples.size
      
      # Use min-max downsampling to preserve peaks and valleys
      if skip > 1
        # Process samples in chunks of 'skip' size
        i = 0
        while i < count
          chunk_end = [i + skip, count].min
          chunk = samples[i...chunk_end]
          
          if chunk.any?
            # Find min and max in this chunk
            min_val = chunk.min
            max_val = chunk.max
            min_idx = chunk.index(min_val)
            max_idx = chunk.index(max_val)
            
            # Calculate timestamps based on continuous sample count (ignore batch gaps)
            ts_min = recording_start.to_f + ((cumulative_samples + i + min_idx) * time_per_sample)
            ts_max = recording_start.to_f + ((cumulative_samples + i + max_idx) * time_per_sample)
            
            # Add both min and max to preserve shape
            # Add in chronological order
            if min_idx < max_idx
              # Min comes first
              data << { x: (ts_min * 1000).round, y: min_val } if ts_min >= start_time.to_f && ts_min <= end_time.to_f
              data << { x: (ts_max * 1000).round, y: max_val } if ts_max >= start_time.to_f && ts_max <= end_time.to_f
            else
              # Max comes first
              data << { x: (ts_max * 1000).round, y: max_val } if ts_max >= start_time.to_f && ts_max <= end_time.to_f
              data << { x: (ts_min * 1000).round, y: min_val } if ts_min >= start_time.to_f && ts_min <= end_time.to_f
            end
          end
          
          i += skip
        end
      else
        # No downsampling needed, take all samples
        i = 0
        while i < count
          # Calculate timestamp based on continuous sample count (ignore batch gaps)
          ts = recording_start.to_f + ((cumulative_samples + i) * time_per_sample)
          if ts >= start_time.to_f && ts <= end_time.to_f
            data << { x: (ts * 1000).round, y: samples[i] }
          end
          i += 1
        end
      end
      
      # Update cumulative count for next batch
      cumulative_samples += count
    end
    
    # Sort data by timestamp to ensure correct drawing order
    data.sort_by! { |point| point[:x] }
    
    # Add caching headers for completed recordings
    if @recording.status == 'completed'
      expires_in 1.hour, public: true
    else
      # Short cache for active recordings
      expires_in 10.seconds, public: true
    end
    
    render json: {
      type: 'raw',
      data: data,
      meta: {
        start_time: start_time.iso8601(3),
        end_time: end_time.iso8601(3),
        sample_count: data.size,
        skip_factor: skip,
        recording_status: @recording.status
      }
    }
  end

  private

  def require_medical_staff
    unless current_user.medical_staff? || current_user.hospital_manager? || current_user.superuser?
      redirect_to root_path, alert: 'Akses ditolak. Halaman ini hanya untuk petugas medis.'
    end
  end

  def set_recording
    @recording = Recording.find(params[:id])
  end

  def can_view_recording?(recording)
    return true if current_user.superuser?
    return true if current_user.hospital_manager?
    return true if current_user.medical_staff
    return true if current_user.patient? && recording.patient == current_user.patient
    false
  end
end
