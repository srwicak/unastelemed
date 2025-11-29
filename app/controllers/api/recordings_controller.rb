class Api::RecordingsController < ApplicationController
  skip_before_action :verify_authenticity_token
  skip_before_action :authenticate_user!
  # Require authentication for most API endpoints. Keep start/data/stop/show public for device flow.
  # Note: `index` now requires authentication so mobile users can only fetch their own recordings (or doctors).
  before_action :authenticate_request, except: [:show, :start, :data, :stop, :recover_data]
  before_action :set_recording, only: [:show, :update, :destroy, :chart_data, :complete, :cancel, :add_interpretation, :add_notes, :recover_data]
  before_action :set_recording_for_stop_and_data, only: [:stop, :data]
  
  def index
    # Ensure user is authenticated
    unless authenticate_request
      return render json: { success: false, error: 'Unauthorized', message: 'Invalid or missing authentication token' }, status: :unauthorized
    end

    # Determine target user (user_id param refers to User.id of the patient)
    target_user_id = params[:user_id] || @current_user&.id

    target_user = User.find_by(id: target_user_id)
    unless target_user
      return render json: { success: false, error: 'User not found', message: "User with id '#{target_user_id}' does not exist" }, status: :not_found
    end

    # Authorization: only the same user (patient) or a doctor can access another user's recordings
    unless @current_user.id == target_user.id || @current_user.role == 'doctor'
      return render json: { success: false, error: 'Forbidden', message: "You cannot access another user's recordings" }, status: :forbidden
    end

    # Map user -> patient (recordings are linked to patients)
    patient = Patient.find_by(user_id: target_user.id)

    recordings_scope = if patient
      Recording.includes(:patient, :hospital, :qr_code, recording_session: :medical_staff)
               .where(patient_id: patient.id)
    else
      Recording.none
    end

    # Optional status filter
    recordings_scope = recordings_scope.where(status: params[:status]) if params[:status].present?

    recordings = recordings_scope.order(created_at: :desc).page(params[:page]).per(params[:per_page] || 20)

    render json: {
      success: true,
      recordings: recordings.map { |r| recording_data(r) },
      meta: pagination_data(recordings)
    }, status: :ok
  end
  
  def show
    render json: {
      success: true,
      data: {
        recording: recording_data(@recording)
      }
    }, status: :ok
  end
  
  def create
    @recording = Recording.new(recording_params)
    
    if @recording.save
      render json: {
        success: true,
        message: 'Recording created successfully',
        data: {
          recording: recording_data(@recording)
        }
      }, status: :created
    else
      render json: {
        success: false,
        message: 'Recording creation failed',
        errors: @recording.errors.full_messages
      }, status: :unprocessable_entity
    end
  end
  
  def update
    if @recording.update(recording_update_params)
      render json: {
        success: true,
        message: 'Recording updated successfully',
        data: {
          recording: recording_data(@recording)
        }
      }, status: :ok
    else
      render json: {
        success: false,
        message: 'Recording update failed',
        errors: @recording.errors.full_messages
      }, status: :unprocessable_entity
    end
  end
  
  # POST /api/recordings/start
  # Start recording from mobile app
  def start
    # Support multiple parameter formats for backward compatibility
    recording_params = params[:recording] || params
    
    qr_code_payload = recording_params[:qr_code] || params[:qr_code] || params[:qr_payload]
    session_id = recording_params[:qr_session_id] || recording_params[:session_id] || params[:session_id]
    device_id = recording_params[:device_id] || params[:device_id]
    device_name = recording_params[:device_name] || params[:device_name]
    user_id = recording_params[:user_id] || params[:user_id]
    sample_rate = recording_params[:sample_rate] || params[:sample_rate] || 400.0
    start_time = recording_params[:start_time] || params[:start_time]
    
    # Try to find QR code by session_id if provided
    qr_code = nil
    recording_session = nil
    
    if session_id.present?
      # Optimized: First find recording_session, then find QR code with includes
      # This avoids the slow JOIN operation and N+1 queries
      recording_session = RecordingSession.find_by(session_id: session_id)
      if recording_session
        qr_code = QrCode.includes(:patient, :hospital).find_by(recording_session_id: recording_session.id)
      end
    end
    
    # If not found and qr_code_payload provided, try parsing it
    if qr_code.nil? && qr_code_payload.present?
      begin
        # Parse QR code if it's JSON string
        qr_data = qr_code_payload.is_a?(String) ? JSON.parse(qr_code_payload) : qr_code_payload
        
        # Try finding by code or session_id from payload
        qr_code = QrCode.find_by(code: qr_data['code']) if qr_data['code'].present?
        if qr_code.nil? && qr_data['session_id'].present?
          # Optimized: Avoid JOIN, use direct lookup
          recording_session = RecordingSession.find_by(session_id: qr_data['session_id'])
          qr_code = QrCode.find_by(recording_session_id: recording_session.id) if recording_session
        end
      rescue JSON::ParserError => e
        return render json: {
          success: false,
          error: 'Format QR code tidak valid',
          details: e.message
        }, status: :bad_request
      end
    end
    
    unless qr_code
      return render json: {
        success: false,
        error: 'QR code tidak ditemukan. Session ID: ' + (session_id || 'tidak ada').to_s
      }, status: :not_found
    end
    
    # Validate QR code
    if qr_code.is_used
      return render json: {
        success: false,
        error: 'QR code sudah digunakan'
      }, status: :unprocessable_entity
    end
    
    if qr_code.expired?
      return render json: {
        success: false,
        error: 'QR code sudah expired'
      }, status: :unprocessable_entity
    end
    
    # Find or get session
    recording_session ||= qr_code.recording_session
    
    unless recording_session
      return render json: {
        success: false,
        error: 'Recording session tidak ditemukan'
      }, status: :not_found
    end
    
    begin
      # Generate unique session_id if not provided
      generated_session_id = recording_session.session_id || "recording_#{SecureRandom.hex(8)}_#{Time.current.to_i}"
      
      # Check if recording already exists for this session
      existing_recording = Recording.find_by(session_id: generated_session_id)
      if existing_recording
        # If recording exists and is still active, return it instead of creating a new one
        if existing_recording.status.in?(['pending', 'recording'])
          upload_session = existing_recording.upload_session
          
          # Create upload session if it doesn't exist
          unless upload_session
            upload_id = "upload_#{SecureRandom.hex(16)}"
            upload_session = UploadSession.create!(
              recording_id: existing_recording.id,
              upload_id: upload_id,
              session_id: existing_recording.session_id,
              file_name: "recording_#{existing_recording.session_id}.csv",
              file_size: 0,
              chunk_size: 1048576,
              total_chunks: 0,
              file_sha256: '',
              status: 'pending'
            )
          end
          
          return render json: {
            success: true,
            message: 'Recording sudah dimulai sebelumnya (menggunakan recording yang ada)',
            data: {
              recording_id: existing_recording.id,
              session_id: existing_recording.session_id,
              upload_token: upload_session.upload_id,
              patient: {
                id: qr_code.patient.id,
                name: qr_code.patient.name,
                patient_identifier: qr_code.patient.patient_identifier
              },
              max_duration_seconds: qr_code.duration_in_seconds,
              sample_rate: existing_recording.sample_rate,
              started_at: existing_recording.start_time
            }
          }, status: :ok
        else
          # Recording exists but already completed/failed, generate new session_id
          generated_session_id = "recording_#{SecureRandom.hex(8)}_#{Time.current.to_i}"
        end
      end
      
      # Create new recording
      # Use QR code's healthcare_provider_id as the primary source for user_id
      # since it's validated and guaranteed to exist
      recording_user_id = if qr_code.healthcare_provider_type == 'User'
        qr_code.healthcare_provider_id
      else
        # If healthcare_provider is MedicalStaff, get their associated user_id
        medical_staff = MedicalStaff.find_by(id: qr_code.healthcare_provider_id)
        medical_staff&.user_id || user_id
      end
      
      @recording = Recording.create!(
        patient_id: qr_code.patient_id,
        hospital_id: qr_code.hospital_id,
        user_id: recording_user_id,
        session_id: generated_session_id,
        status: 'recording',
        start_time: start_time ? Time.zone.parse(start_time) : Time.current,
        sample_rate: sample_rate.to_f
      )
      
      # Create upload session for this recording
      upload_id = "upload_#{SecureRandom.hex(16)}"
      upload_session = UploadSession.create!(
        recording_id: @recording.id,
        upload_id: upload_id,
        session_id: @recording.session_id,
        file_name: "recording_#{@recording.session_id}.csv",
        file_size: 0, # Will be updated as chunks are received
        chunk_size: 1048576, # 1MB default chunk size
        total_chunks: 0, # Will be updated when upload completes
        file_sha256: '', # Will be calculated on complete
        status: 'pending'
      )
      
      # Mark QR code as used
      qr_code.update!(is_used: true, used_at: Time.current)
      
      render json: {
        success: true,
        message: 'Recording dimulai',
        data: {
          recording_id: @recording.id,
          session_id: @recording.session_id,
          upload_token: upload_id,
          patient: {
            id: qr_code.patient.id,
            name: qr_code.patient.name,
            patient_identifier: qr_code.patient.patient_identifier
          },
          max_duration_seconds: qr_code.duration_in_seconds,
          sample_rate: @recording.sample_rate,
          started_at: @recording.start_time
        }
      }, status: :created
      
    rescue StandardError => e
      render json: {
        success: false,
        error: 'Terjadi kesalahan saat membuat recording',
        details: e.message
      }, status: :internal_server_error
    end
  end
  
  # POST /api/recordings/data
  # Receive sensor data from mobile app
  def data
    recording_id = params[:recording_id]
    samples = params[:samples] || []
    
    # New: support for batch format
    batch_data = params[:batch_data]
    
    unless recording_id
      return render json: {
        success: false,
        error: 'Recording ID tidak ditemukan'
      }, status: :bad_request
    end
    
    @recording = Recording.find_by(id: recording_id)
    
    unless @recording
      return render json: {
        success: false,
        error: 'Recording tidak ditemukan'
      }, status: :not_found
    end
    
    unless @recording.status == 'recording'
      return render json: {
        success: false,
        error: 'Recording tidak dalam status recording',
        current_status: @recording.status
      }, status: :unprocessable_entity
    end
    
    begin
      # Check if batch format is provided (NEW FORMAT - RECOMMENDED)
      if batch_data.present?
        result = process_batch_data(batch_data)
        
        # Use 200 OK for duplicate batches, 201 Created for new batches
        status_code = result[:is_duplicate] ? :ok : :created
        message = result[:is_duplicate] ? 'Batch data sudah ada (duplicate)' : 'Batch data berhasil disimpan'
        
        render json: {
          success: true,
          message: message,
          data: {
            recording_id: @recording.id,
            batch_sequence: result[:batch_sequence],
            samples_received: result[:samples_count],
            is_duplicate: result[:is_duplicate],
            total_batches: @recording.biopotential_batches.count,
            total_samples: @recording.total_samples
          }
        }, status: status_code
        
      # Legacy format: individual samples (SLOWER, for backward compatibility)
      elsif samples.present?
        result = process_individual_samples(samples)
        
        render json: {
          success: true,
          message: 'Data berhasil disimpan',
          data: {
            recording_id: @recording.id,
            samples_received: samples.length,
            samples_saved: result[:saved_count],
            total_samples: @recording.total_samples
          }
        }, status: :created
        
      else
        render json: {
          success: false,
          error: 'Tidak ada data yang dikirim. Gunakan format batch_data atau samples'
        }, status: :bad_request
      end
      
    rescue StandardError => e
      render json: {
        success: false,
        error: 'Gagal menyimpan data',
        details: Rails.env.development? ? e.message : nil
      }, status: :internal_server_error
    end
  end
  
  # POST /api/recordings/stop (collection)
  # POST /api/recordings/:id/stop (member)
  # Stop recording from mobile app
  def stop
    # For collection route, find recording by recording_id or session_id parameter
    if params[:id].blank?
      recording_id = params[:recording_id] || params[:recording]&.dig(:recording_id)
      session_id = params[:session_id] || params[:recording]&.dig(:session_id)
      
      if recording_id.present?
        @recording = Recording.find_by(id: recording_id)
      elsif session_id.present?
        @recording = Recording.find_by(session_id: session_id)
      end
      
      unless @recording
        return render json: {
          success: false,
          error: 'Recording tidak ditemukan. Kirim recording_id atau session_id'
        }, status: :not_found
      end
    end
    
    unless @recording.status == 'recording'
      return render json: {
        success: false,
        error: 'Recording tidak dalam status recording',
        current_status: @recording.status
      }, status: :unprocessable_entity
    end
    
    # NEW: Process batch data if sent with stop request (workaround for mobile app)
    batches_param = params[:batches] || params[:recording]&.dig(:batches)
    if batches_param.present? && batches_param.is_a?(Array)
      Rails.logger.info "Processing #{batches_param.size} batches sent with stop request"
      
      batches_param.each_with_index do |batch_data, index|
        begin
          process_batch_data(batch_data)
          Rails.logger.info "Processed batch #{index + 1}/#{batches_param.size}"
        rescue StandardError => e
          Rails.logger.error "Error processing batch #{index}: #{e.message}"
          # Continue processing other batches even if one fails
        end
      end
    end
    
    end_time = Time.current
    duration_seconds = (end_time - @recording.start_time).to_i
    
    if @recording.update(
      status: 'completed',
      end_time: end_time,
      duration_seconds: duration_seconds
    )
      # Reload to get updated attributes
      @recording.reload
      
      render json: {
        success: true,
        message: 'Recording selesai',
        data: {
          recording_id: @recording.id,
          session_id: @recording.session_id,
          status: @recording.status,
          started_at: @recording.start_time,
          ended_at: @recording.end_time,
          duration_seconds: duration_seconds,
          total_samples: @recording.total_samples,
          total_batches: @recording.biopotential_batches.count
        }
      }, status: :ok
    else
      render json: {
        success: false,
        error: 'Gagal menghentikan recording',
        errors: @recording.errors.full_messages
      }, status: :unprocessable_entity
    end
  end
  
  def destroy
    @recording.destroy
    render json: {
      success: true,
      message: 'Recording deleted successfully'
    }, status: :ok
  end
  
  def complete
    if @recording.update(status: 'completed', ended_at: Time.current)
      render json: {
        success: true,
        message: 'Recording completed successfully',
        data: {
          recording: recording_data(@recording)
        }
      }, status: :ok
    else
      render json: {
        success: false,
        message: 'Failed to complete recording'
      }, status: :unprocessable_entity
    end
  end
  
  def cancel
    if @recording.update(status: 'cancelled', ended_at: Time.current)
      render json: {
        success: true,
        message: 'Recording cancelled successfully'
      }, status: :ok
    else
      render json: {
        success: false,
        message: 'Failed to cancel recording'
      }, status: :unprocessable_entity
    end
  end
  
  # POST /api/recordings/:id/recover_data
  # Endpoint untuk mobile app mengirim data yang tertinggal
  def recover_data
    batches_param = params[:batches] || []
    
    unless batches_param.is_a?(Array) && batches_param.any?
      return render json: {
        success: false,
        error: 'Batches data tidak ditemukan atau kosong',
        message: 'Kirim array of batch_data dalam parameter batches'
      }, status: :bad_request
    end
    
    processed_batches = []
    failed_batches = []
    duplicate_batches = []
    
    batches_param.each_with_index do |batch_data, index|
      begin
        result = process_batch_data(batch_data)
        
        if result[:is_duplicate]
          duplicate_batches << {
            batch_sequence: result[:batch_sequence],
            message: 'Batch sudah ada'
          }
        else
          processed_batches << {
            batch_sequence: result[:batch_sequence],
            samples_count: result[:samples_count]
          }
        end
        
        Rails.logger.info "Recovery: Processed batch #{index + 1}/#{batches_param.size}"
      rescue StandardError => e
        Rails.logger.error "Recovery: Error processing batch #{index}: #{e.message}"
        failed_batches << {
          batch_sequence: batch_data['batch_sequence'] || index,
          error: e.message
        }
      end
    end
    
    # Reload to get updated counts
    @recording.reload
    
    render json: {
      success: true,
      message: 'Data recovery selesai',
      data: {
        recording_id: @recording.id,
        session_id: @recording.session_id,
        processed_count: processed_batches.size,
        duplicate_count: duplicate_batches.size,
        failed_count: failed_batches.size,
        total_batches: @recording.biopotential_batches.count,
        total_samples: @recording.total_samples,
        processed_batches: processed_batches,
        duplicate_batches: duplicate_batches,
        failed_batches: failed_batches
      }
    }, status: :ok
  end
  
  def chart_data
    # Get chart data for visualization
    time_range = params[:time_range] || 'full'
    resolution = params[:resolution] || 'high'
    start_time = params[:start_time] ? Time.zone.parse(params[:start_time]) : nil
    end_time = params[:end_time] ? Time.zone.parse(params[:end_time]) : nil
    
    # Use batch data for faster retrieval (NEW - OPTIMIZED)
    if @recording.biopotential_batches.any?
      batches = @recording.biopotential_batches.ordered
      
      # Filter by time range if specified
      if start_time && end_time
        batches = batches.by_time_range(start_time, end_time)
      end
      
      # Limit batches based on resolution
      batch_limit = case resolution
      when 'low'
        10  # ~100 seconds of data
      when 'medium'
        60  # ~10 minutes of data
      else # 'high'
        600 # ~100 minutes of data
      end
      
      batches = batches.limit(batch_limit)
      
      chart_data = {
        recording_id: @recording.id,
        duration_seconds: @recording.duration_seconds,
        sample_rate: @recording.sample_rate,
        data_format: 'batch',
        batches: []
      }
      
      batches.each do |batch|
        samples = batch.samples
        
        # Downsample if needed
        if resolution == 'low'
          samples = batch.downsample(10)
        elsif resolution == 'medium'
          samples = batch.downsample(5)
        end
        
        chart_data[:batches] << {
          batch_sequence: batch.batch_sequence,
          start_timestamp: batch.start_timestamp.to_f * 1000, # milliseconds for JS
          end_timestamp: batch.end_timestamp.to_f * 1000,
          sample_count: samples.size,
          samples: samples
        }
      end
      
      render json: {
        success: true,
        data: chart_data
      }, status: :ok
      
    # Fallback to old individual samples format (LEGACY)
    else
      samples = case resolution
      when 'low'
        @recording.biopotential_samples.order(:sequence_number).limit(1000)
      when 'medium'
        @recording.biopotential_samples.order(:sequence_number).limit(5000)
      else # high
        @recording.biopotential_samples.order(:sequence_number).limit(20000)
      end
      
      chart_data = {
        recording_id: @recording.id,
        duration_seconds: @recording.duration_seconds,
        sample_rate: @recording.sample_rate,
        data_format: 'individual',
        timestamps: [],
        samples: []
      }
      
      samples.each do |sample|
        chart_data[:timestamps] << sample.timestamp.to_f * 1000 # Convert to milliseconds
        chart_data[:samples] << sample.sample_value
      end
      
      render json: {
        success: true,
        data: chart_data
      }, status: :ok
    end
  end
  
  def add_interpretation
    if @recording.update(interpretation: params[:interpretation], interpreted_by_id: @current_user.id, interpreted_at: Time.current)
      render json: {
        success: true,
        message: 'Interpretation added successfully',
        data: {
          recording: recording_data(@recording)
        }
      }, status: :ok
    else
      render json: {
        success: false,
        message: 'Failed to add interpretation',
        errors: @recording.errors.full_messages
      }, status: :unprocessable_entity
    end
  end
  
  def add_notes
    if @recording.update(notes: params[:notes])
      render json: {
        success: true,
        message: 'Notes added successfully',
        data: {
          recording: recording_data(@recording)
        }
      }, status: :ok
    else
      render json: {
        success: false,
        message: 'Failed to add notes',
        errors: @recording.errors.full_messages
      }, status: :unprocessable_entity
    end
  end
  
  private
  
  # Authenticate JWT token from Authorization header
  def authenticate_request
    header = request.headers['Authorization']
    token = header&.split(' ')&.last
    
    return false unless token.present?
    
    begin
      decoded = JWT.decode(token, Rails.application.credentials.secret_key_base, true, { algorithm: 'HS256' })
      user_id = decoded[0]['user_id']
      @current_user = User.find_by(id: user_id)
      
      return false unless @current_user.present?
      
      # Check if token is expired (additional safety check)
      exp = decoded[0]['exp']
      return false if exp.present? && Time.at(exp) < Time.current
      
      true
    rescue JWT::DecodeError, JWT::ExpiredSignature
      false
    end
  end
  
  def set_recording
    @recording = Recording.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: {
      success: false,
      message: 'Recording not found'
    }, status: :not_found
  end
  
  def set_recording_for_stop_and_data
    # Only set recording if :id param exists (member route)
    if params[:id].present?
      @recording = Recording.find(params[:id])
    end
  rescue ActiveRecord::RecordNotFound
    render json: {
      success: false,
      message: 'Recording not found'
    }, status: :not_found
  end
  
  # Process batch data (NEW - OPTIMIZED for 500Hz data)
  def process_batch_data(batch_data)
    start_time = Time.zone.parse(batch_data['start_timestamp']) rescue Time.current
    end_time = Time.zone.parse(batch_data['end_timestamp']) rescue (start_time + 10.seconds)
    samples = batch_data['samples'] || []
    batch_sequence = batch_data['batch_sequence'] || @recording.biopotential_batches.count
    sample_rate = batch_data['sample_rate'] || @recording.sample_rate || 400.0
    
    # Validate max samples per batch (prevent abuse)
    max_samples = 10_000
    if samples.size > max_samples
      raise StandardError, "Terlalu banyak samples dalam 1 batch. Max: #{max_samples}"
    end
    
    # Use find_or_initialize_by to handle duplicate batch sequences (idempotent)
    # This prevents errors when Flutter retries sending the same batch
    batch = BiopotentialBatch.find_or_initialize_by(
      recording_id: @recording.id,
      batch_sequence: batch_sequence
    )
    
    # Track if this is a new batch (for total_samples calculation)
    is_new_batch = batch.new_record?
    
    # Update/set batch attributes
    batch.assign_attributes(
      start_timestamp: start_time,
      end_timestamp: end_time,
      sample_rate: sample_rate,
      sample_count: samples.size,
      data: { samples: samples }
    )
    
    batch.save!
    
    # Only update total samples if this is a new batch
    if is_new_batch
      new_total = (@recording.total_samples || 0) + samples.size
      @recording.update!(total_samples: new_total)
    end
    
    {
      batch_id: batch.id,
      batch_sequence: batch.batch_sequence,
      samples_count: samples.size,
      is_duplicate: !is_new_batch
    }
  end
  
  # Process individual samples (LEGACY - kept for backward compatibility)
  def process_individual_samples(samples)
    # Validate max samples
    max_samples = 10_000
    if samples.size > max_samples
      raise StandardError, "Terlalu banyak samples. Max: #{max_samples}"
    end
    
    # Use bulk insert for better performance
    samples_data = samples.map.with_index do |sample_data, idx|
      {
        recording_id: @recording.id,
        timestamp: sample_data['timestamp'] || Time.current,
        sample_value: sample_data['value'],
        sequence_number: sample_data['sequence'] || ((@recording.total_samples || 0) + idx),
        created_at: Time.current,
        updated_at: Time.current
      }
    end
    
    BiopotentialSample.insert_all(samples_data) if samples_data.any?
    
    # Update recording total samples
    @recording.update!(total_samples: (@recording.total_samples || 0) + samples.size)
    
    {
      saved_count: samples.size
    }
  end
  
  def recording_params
    params.permit(
      :patient_id,
      :patient_type,
      :hospital_id,
      :healthcare_provider_id,
      :healthcare_provider_type,
      :qr_code_id,
      :device_id,
      :device_name,
      :status,
      :started_at,
      :ended_at,
      :duration_in_seconds,
      :max_duration_minutes,
      :file_path,
      :file_size,
      :file_format,
      :notes,
      :interpretation,
      :interpreted_by_id,
      :interpreted_at
    )
  end
  
  def recording_update_params
    params.permit(
      :status,
      :ended_at,
      :duration_in_seconds,
      :notes,
      :interpretation,
      :interpreted_by_id,
      :interpreted_at
    )
  end
  
  def recording_data(recording)
    recording_session = recording.recording_session
    medical_staff = recording_session&.medical_staff

    # Use RecordingSession fields if available, otherwise fall back to Recording direct fields
    reviewed_by_doctor = recording.reviewed_by_doctor || recording_session&.interpretation_completed || false
    doctor_id_value = recording.doctor_id || medical_staff&.user_id
    doctor_name_value = if recording.doctor_id
      recording.doctor&.name
    else
      medical_staff&.name
    end
    reviewed_at_value = recording.reviewed_at || recording_session&.updated_at
    has_notes_value = recording.has_notes || recording_session&.doctor_notes.present? || false
    doctor_notes_value = recording.doctor_notes || recording_session&.doctor_notes
    diagnosis_value = recording.diagnosis || recording_session&.diagnosis

    {
      id: recording.id,
      user_id: recording.user_id,
      device_id: nil, # Not stored currently
      start_time: recording.start_time,
      end_time: recording.end_time,
      duration: recording.duration_seconds,
      data_points: recording.total_samples,
      location: recording.hospital&.name,
      status: recording.status,
      
      # Doctor review fields (mandatory per mobile task)
      reviewed_by_doctor: reviewed_by_doctor,
      doctor_id: doctor_id_value,
      doctor_name: doctor_name_value,
      reviewed_at: reviewed_at_value,
      has_notes: has_notes_value,
      doctor_notes: doctor_notes_value,
      diagnosis: diagnosis_value,
      
      created_at: recording.created_at,
      updated_at: recording.updated_at
    }
  end
  
  def session_data(recording)
    {
      id: recording.id,
      user_id: recording.patient_id,
      qr_code_id: recording.qr_code_id,
      status: recording.status,
      started_at: recording.started_at,
      ended_at: recording.ended_at,
      duration_minutes: recording.duration_in_seconds ? (recording.duration_in_seconds / 60).round : nil,
      created_at: recording.created_at
    }
  end
  
  def sample_data(sample)
    {
      id: sample.id,
      recording_id: sample.recording_id,
      timestamp: sample.timestamp,
      channel_1: sample.channel_1,
      channel_2: sample.channel_2,
      channel_3: sample.channel_3,
      channel_4: sample.channel_4,
      channel_5: sample.channel_5,
      channel_6: sample.channel_6,
      channel_7: sample.channel_7,
      channel_8: sample.channel_8,
      created_at: sample.created_at
    }
  end
  
  def pagination_data(scope)
    {
      current_page: scope.current_page,
      next_page: scope.next_page,
      prev_page: scope.prev_page,
      total_pages: scope.total_pages,
      total_count: scope.total_count
    }
  end
  
  def batch_data(batch)
    {
      id: batch.id,
      batch_sequence: batch.batch_sequence,
      start_timestamp: batch.start_timestamp.iso8601(3),
      end_timestamp: batch.end_timestamp.iso8601(3),
      sample_rate: batch.sample_rate,
      sample_count: batch.sample_count,
      duration_seconds: batch.duration_seconds,
      samples: batch.samples,
      statistics: batch.statistics
    }
  end
end