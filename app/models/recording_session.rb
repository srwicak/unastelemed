class RecordingSession < ApplicationRecord
  belongs_to :patient
  belongs_to :medical_staff
  has_one :qr_code
  has_many :recordings, primary_key: :session_id, foreign_key: :session_id
  
  before_create :generate_session_id
  
  validates :status, presence: true, inclusion: { in: %w[active completed cancelled] }
  validates :patient_id, presence: true
  validates :medical_staff_id, presence: true
  validates :session_id, uniqueness: true, allow_nil: true
  
  def active?
    status == 'active'
  end
  
  def completed?
    status == 'completed'
  end
  
  def cancelled?
    status == 'cancelled'
  end
  
  def can_add_recording?
    active? && !expired?
  end
  
  def expired?
    return false unless qr_code&.expires_at
    Time.current > qr_code.expires_at
  end
  
  def duration_minutes
    return nil unless started_at && ended_at
    ((ended_at - started_at) / 60).round
  end
  
  def formatted_duration
    return "Belum selesai" unless completed?
    return "-" unless duration_minutes
    
    if duration_minutes < 60
      "#{duration_minutes} menit"
    else
      hours = duration_minutes / 60
      minutes = duration_minutes % 60
      "#{hours} jam #{minutes} menit"
    end
  end
  
  private
  
  def generate_session_id
    self.session_id ||= "session_#{SecureRandom.hex(12)}"
  end
end