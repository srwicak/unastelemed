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
