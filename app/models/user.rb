class User < ApplicationRecord
  has_secure_password
  
  # Associations
  has_many :recordings, dependent: :destroy
  has_many :qr_codes, as: :healthcare_provider, dependent: :destroy
  belongs_to :hospital, optional: true
  has_one :patient, dependent: :destroy
  has_one :medical_staff, dependent: :destroy
  
  # Nested attributes
  accepts_nested_attributes_for :patient
  
  # Validations
  validates :email, presence: true, uniqueness: { case_sensitive: false }
  validates :name, presence: true
  validates :role, presence: true, inclusion: { in: %w[patient nurse doctor hospital_manager superuser] }
  validates :medical_record_number, uniqueness: true, allow_nil: true
  validates :patient_identifier, uniqueness: true, presence: true
  
  # Scopes
  scope :patients, -> { where(role: 'patient') }
  scope :medical_staff, -> { where(role: %w[doctor nurse]) }
  scope :doctors, -> { where(role: 'doctor') }
  scope :nurses, -> { where(role: 'nurse') }
  scope :hospital_managers, -> { where(role: 'hospital_manager') }
  scope :superusers, -> { where(role: 'superuser') }
  
  # Callbacks
  before_save :downcase_email
  before_validation :generate_patient_identifier, on: :create
  before_validation :sync_patient_name, if: :patient?
  
  def patient?
    role == 'patient'
  end
  
  def doctor?
    role == 'doctor'
  end
  
  def nurse?
    role == 'nurse'
  end
  
  def hospital_manager?
    role == 'hospital_manager'
  end
  
  def superuser?
    role == 'superuser'
  end
  
  def medical_staff?
    %w[doctor nurse].include?(role)
  end
  
  def can_manage_staff?
    %w[hospital_manager superuser].include?(role)
  end
  
  def can_manage_hospital?
    %w[hospital_manager superuser].include?(role)
  end
  
  def generate_jwt_token
    JWT.encode(
      { 
        user_id: id, 
        exp: 24.hours.from_now.to_i,
        role: role
      },
      Rails.application.credentials.secret_key_base
    )
  end
  
  private
  
  def downcase_email
    self.email = email.downcase if email.present?
  end
  
  def generate_patient_identifier
    return if patient_identifier.present?
    
    require 'nanoid'
    self.patient_identifier = loop do
      candidate = Nanoid.generate(size: 12)
      break candidate unless User.exists?(patient_identifier: candidate)
    end
  end
  
  def sync_patient_name
    if patient.present? && name.present?
      patient.name = name
    end
  end
end