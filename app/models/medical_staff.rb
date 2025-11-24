class MedicalStaff < ApplicationRecord
  belongs_to :user
  belongs_to :hospital, optional: true
  
  has_many :recording_sessions
  has_many :patients, through: :recording_sessions
  
  validates :name, presence: true
  validates :role, presence: true, inclusion: { in: %w[doctor nurse admin] }
  validates :license_number, presence: true, uniqueness: true
  validates :specialization, presence: true
  validates :approval_status, inclusion: { in: %w[pending approved rejected] }, allow_nil: true
  
  # Scopes
  scope :pending, -> { where(approval_status: 'pending') }
  scope :approved, -> { where(approval_status: 'approved') }
  scope :rejected, -> { where(approval_status: 'rejected') }
  
  def doctor?
    role == 'doctor'
  end
  
  def nurse?
    role == 'nurse'
  end
  
  def admin?
    role == 'admin'
  end
  
  def approved?
    approval_status == 'approved'
  end
  
  def pending?
    approval_status == 'pending'
  end
  
  def rejected?
    approval_status == 'rejected'
  end
  
  def full_title
    case role
    when 'doctor'
      "Dr. #{name}"
    when 'nurse'
      "Perawat #{name}"
    else
      name
    end
  end
end