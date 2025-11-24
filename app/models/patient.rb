class Patient < ApplicationRecord
  belongs_to :user
  
  has_many :recording_sessions
  has_many :recordings, through: :recording_sessions
  has_many :medical_staffs, through: :recording_sessions
  
  before_create :generate_patient_identifier
  
  validates :name, presence: true
  validates :date_of_birth, presence: true
  validates :gender, presence: true, inclusion: { in: %w[male female] }
  validates :phone_number, presence: true
  validates :address, presence: true
  validates :emergency_contact, presence: true
  validates :patient_identifier, uniqueness: true, allow_nil: true
  
  def age
    return nil unless date_of_birth
    
    today = Date.current
    age = today.year - date_of_birth.year
    age -= 1 if today < date_of_birth + age.years
    age
  end
  
  def formatted_date_of_birth
    date_of_birth.strftime('%d %B %Y') if date_of_birth
  end
  
  def recent_sessions(limit = 5)
    recording_sessions.order(created_at: :desc).limit(limit)
  end
  
  def completed_sessions
    recording_sessions.where(status: 'completed')
  end
  
  def active_sessions
    recording_sessions.where(status: 'active')
  end
  
  private
  
  def generate_patient_identifier
    self.patient_identifier = Nanoid.generate(size: 12)
  end
end