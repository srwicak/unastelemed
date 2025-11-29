class Recording < ApplicationRecord
  belongs_to :patient
  belongs_to :hospital
  belongs_to :user, optional: true # The medical staff who created the session
  belongs_to :doctor, class_name: 'User', optional: true # Doctor who reviewed
  belongs_to :qr_code, optional: true
  belongs_to :recording_session, primary_key: :session_id, foreign_key: :session_id, optional: true
  has_one :upload_session, dependent: :destroy
  has_many :biopotential_samples, dependent: :destroy
  has_many :biopotential_batches, dependent: :destroy
  has_many :ekg_markers, dependent: :destroy
  has_many :biopotential_batches, dependent: :destroy
  
  # Validations
  validates :session_id, presence: true, uniqueness: { case_sensitive: false }
  validates :status, presence: true, inclusion: { in: %w[pending recording uploading processing completed failed cancelled] }
  validates :patient_id, presence: true
  validates :hospital_id, presence: true
  
  # Scopes
  scope :pending, -> { where(status: 'pending') }
  scope :recording, -> { where(status: 'recording') }
  scope :uploading, -> { where(status: 'uploading') }
  scope :processing, -> { where(status: 'processing') }
  scope :completed, -> { where(status: 'completed') }
  scope :failed, -> { where(status: 'failed') }
  scope :cancelled, -> { where(status: 'cancelled') }
  scope :recent, -> { order(created_at: :desc) }
  scope :for_patient, ->(patient_id) { where(patient_id: patient_id) }
  scope :reviewed, -> { where(reviewed_by_doctor: true) }
  scope :not_reviewed, -> { where(reviewed_by_doctor: false) }
  scope :with_notes, -> { where(has_notes: true) }
  
  # Find recordings that might be stale (stuck in 'recording' status)
  scope :stale, -> (threshold_minutes = 15) {
    recording
      .where('start_time < ?', threshold_minutes.minutes.ago)
      .order(start_time: :asc)
  }
  
  # Callbacks
  before_validation :set_default_status, on: :create
  after_update :process_data_if_completed, if: :saved_change_to_status?
  before_save :update_has_notes_flag
  
  def duration_in_seconds
    return 0 unless start_time && end_time
    (end_time - start_time).to_i
  end
  
  def duration_in_minutes
    duration_in_seconds / 60
  end
  
  def duration_in_hours
    duration_in_minutes / 60
  end
  
  def can_upload?
    %w[pending recording uploading].include?(status)
  end
  
  def can_process?
    status == 'uploading' && upload_session&.completed?
  end
  
  def complete_upload!
    update!(status: 'processing') if can_process?
  end
  
  def fail_upload!
    update!(status: 'failed')
  end
  
  def complete_processing!
    update!(
      status: 'completed',
      total_samples: biopotential_samples.count,
      sample_rate: calculate_sample_rate
    )
  end
  
  def data_for_chart(limit: 10000)
    biopotential_samples
      .order(:sequence_number)
      .limit(limit)
      .pluck(:timestamp, :sample_value)
  end
  
  def csv_data
    return nil unless csv_file_path.present? && File.exist?(csv_file_path)
    
    CSV.read(csv_file_path, headers: true)
  end
  
  def csv_file_exists?
    csv_file_path.present? && File.exist?(csv_file_path)
  end
  
  def sample_rate_hz
    return 0 unless sample_rate.present?
    sample_rate.to_f
  end
  
  def time_range
    return nil unless start_time && end_time
    start_time..end_time
  end
  
  def formatted_duration
    return "N/A" unless duration_seconds.present?
    
    hours = duration_seconds / 3600
    minutes = (duration_seconds % 3600) / 60
    seconds = duration_seconds % 60
    
    if hours > 0
      "#{hours}h #{minutes}m"
    elsif minutes > 0
      "#{minutes}m #{seconds}s"
    else
      "#{seconds}s"
    end
  end
  
  # Check if recording has any batch data
  def has_batch_data?
    biopotential_batches.exists?
  end
  
  # Get data completeness status
  def data_status
    return :no_data if !has_batch_data? && status == 'completed'
    return :incomplete if !has_batch_data? && status == 'recording'
    return :partial if has_batch_data? && (total_samples.nil? || total_samples == 0)
    return :complete if has_batch_data?
    :unknown
  end
  
  # Get user-friendly message about data status
  def data_status_message
    case data_status
    when :no_data
      "⚠️ Data EKG tidak tersimpan. Mobile app tidak mengirim data batch selama recording."
    when :incomplete
      "⏳ Recording sedang berlangsung. Menunggu data dari mobile app..."
    when :partial
      "⚠️ Data EKG tidak lengkap. Beberapa batch mungkin tidak terkirim."
    when :complete
      "✓ Data EKG lengkap"
    else
      "❓ Status data tidak diketahui"
    end
  end
  
  # Check if recording exceeded max duration + grace period
  def exceeded_max_duration?
    return false unless status == 'recording'
    return false unless start_time
    return false unless qr_code&.duration_in_seconds
    
    max_duration = qr_code.duration_in_seconds
    grace_period = calculate_grace_period(max_duration)
    total_allowed = max_duration + grace_period
    
    elapsed = Time.current - start_time
    elapsed > total_allowed
  end
  
  # Calculate grace period based on recording duration (proportional)
  def calculate_grace_period(duration_seconds)
    case duration_seconds
    when 0..60          # <= 1 minute: grace = 1 minute
      60
    when 61..300        # 1-5 minutes: grace = 1 minute
      60
    when 301..600       # 5-10 minutes: grace = 2 minutes
      120
    when 601..1800      # 10-30 minutes: grace = 5 minutes
      300
    when 1801..3600     # 30-60 minutes: grace = 10 minutes
      600
    when 3601..7200     # 1-2 hours: grace = 15 minutes
      900
    when 7201..14400    # 2-4 hours: grace = 30 minutes
      1800
    else                # > 4 hours: grace = 1 hour
      3600
    end
  end
  
  # Check if recording is stale (stuck in 'recording' status for too long)
  def stale?(threshold_minutes = 15)
    return false unless status == 'recording'
    return false unless start_time
    
    # Priority 1: Check if exceeded max duration + grace period
    return true if exceeded_max_duration?
    
    # Priority 2: Check if started long time ago with no batch activity
    started_long_ago = start_time < threshold_minutes.minutes.ago
    
    # Check if has recent batch activity
    if has_batch_data?
      last_batch = biopotential_batches.order(created_at: :desc).first
      no_recent_activity = last_batch.created_at < threshold_minutes.minutes.ago
      return started_long_ago && no_recent_activity
    end
    
    # No batch data and started long ago
    started_long_ago
  end
  
  # Auto-complete recording if exceeded max duration + grace period
  def auto_complete_if_exceeded!
    return false unless exceeded_max_duration?
    
    max_duration = qr_code.duration_in_seconds
    grace_period = calculate_grace_period(max_duration)
    
    reason = [
      "Recording exceeded maximum duration",
      "Max duration: #{max_duration / 60} minutes",
      "Grace period: #{grace_period / 60} minutes",
      "Auto-completed by system"
    ].join(" | ")
    
    force_complete!(reason: reason)
  end
  
  # Force complete a recording (useful for stale recordings)
  def force_complete!(reason: nil)
    return false unless status == 'recording'
    
    # Determine end_time based on last batch or max_duration
    end_time = if has_batch_data?
      last_batch = biopotential_batches.order(end_timestamp: :desc).first
      last_batch.end_timestamp
    elsif qr_code&.duration_in_seconds
      # Use max_duration as end_time if no batch data
      start_time + qr_code.duration_in_seconds.seconds
    else
      start_time + 1.second
    end
    
    duration_seconds = (end_time - start_time).to_i
    
    # Build notes
    completion_note = [
      "[Force-completed at #{Time.current.iso8601}]",
      "Reason: #{reason || 'Manual completion or auto-recovery'}",
      "Data saved up to: #{end_time.iso8601}",
      "Total batches: #{biopotential_batches.count}",
      "Total samples: #{total_samples || 0}"
    ].join("\n")
    
    update!(
      status: 'completed',
      end_time: end_time,
      duration_seconds: duration_seconds,
      notes: [notes, completion_note].compact.join("\n\n")
    )
  end
  
  private
  
  def set_default_status
    self.status ||= 'pending'
  end
  
  def process_data_if_completed
    return unless status == 'processing'
    
    # This will be handled by a background job
    # For now, we'll just mark it as completed if CSV exists
    if csv_file_exists?
      complete_processing!
    else
      fail_upload!
    end
  end
  
  def calculate_sample_rate
    return 0 unless start_time && end_time && total_samples.present? && total_samples > 0
    
    duration = duration_in_seconds
    return 0 if duration == 0
    
    (total_samples.to_f / duration).round(2)
  end
  
  def update_has_notes_flag
    self.has_notes = doctor_notes.present?
  end
end
