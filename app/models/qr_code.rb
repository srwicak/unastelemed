class QrCode < ApplicationRecord
  belongs_to :hospital
  belongs_to :healthcare_provider, polymorphic: true
  belongs_to :patient, polymorphic: true, optional: true
  belongs_to :recording_session, optional: true
  has_many :recordings, dependent: :destroy
  
  # Validations
  validates :code, presence: true, uniqueness: { case_sensitive: false }
  validates :valid_from, presence: true
  validates :valid_until, presence: true
  validates :max_duration_minutes, presence: true, numericality: { greater_than: 0 }
  
  # Scopes
  scope :valid, -> { where('valid_from <= ? AND valid_until >= ?', Time.current, Time.current) }
  scope :unused, -> { where(is_used: false) }
  scope :expired, -> { where('valid_until < ?', Time.current) }
  
  # Callbacks
  before_validation :generate_code, on: :create
  after_create :set_expires_at
  
  def valid_now?
    Time.current.between?(valid_from, valid_until) && !is_used?
  end
  
  def expired?
    valid_until < Time.current
  end
  
  def use!
    update!(is_used: true) unless is_used?
  end
  
  def duration_in_seconds
    max_duration_minutes * 60
  end
  
  def to_qr_svg
    require 'rqrcode'
    
    qr = RQRCode::QRCode.new(qr_payload)
    qr.as_svg(
      offset: 0,
      color: '000',
      shape_rendering: 'crispEdges',
      module_size: 4,
      standalone: true,
      use_path: true,
      viewbox: true
    )
  end
  
  def qr_payload
    # Determine patient_identifier from patient's user account
    patient_id = if patient.present?
      # Get patient_identifier from the User account (for login validation)
      patient.user&.patient_identifier || patient.patient_identifier || "UNKNOWN"
    else
      "UNKNOWN"
    end
    
    payload = {
      session_id: recording_session&.session_id || "session_#{code[0..7]}",
      patient_identifier: patient_id,
      timestamp: created_at.iso8601,
      expiry: valid_until.iso8601,
      device_type: 'CardioGuardian',
      validation_code: code,
      max_duration_seconds: duration_in_seconds
    }
    
    payload.to_json
  end
  
  private
  
  def generate_code
    self.code ||= SecureRandom.hex(16)
  end
  
  def set_expires_at
    self.expires_at = valid_until
    save!
  end
end
