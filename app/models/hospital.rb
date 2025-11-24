class Hospital < ApplicationRecord
  # Associations
  has_many :users, dependent: :destroy
  has_many :recordings, dependent: :destroy
  has_many :qr_codes, dependent: :destroy
  
  # Validations
  validates :name, presence: true
  validates :code, presence: true, uniqueness: { case_sensitive: false }
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
  
  # Callbacks
  before_save :downcase_code
  
  def full_address
    address.presence || "No address provided"
  end
  
  def contact_info
    {
      phone: phone.presence,
      email: email.presence
    }.compact
  end
  
  private
  
  def downcase_code
    self.code = code.downcase if code.present?
  end
end