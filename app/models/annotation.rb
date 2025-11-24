class Annotation < ApplicationRecord
  belongs_to :recording
  belongs_to :created_by, class_name: 'User'
  
  validates :start_time, presence: true
  validates :label, presence: true, length: { minimum: 1, maximum: 100 }
  validates :notes, length: { maximum: 500 }, allow_blank: true
  validate :end_time_after_start_time
  
  # Scope untuk mendapatkan anotasi berdasarkan tipe
  scope :point_markers, -> { where(end_time: nil) }
  scope :range_markers, -> { where.not(end_time: nil) }
  
  def marker_type
    end_time.nil? ? 'point' : 'range'
  end
  
  def duration_seconds
    return 0 if end_time.nil?
    (end_time - start_time).to_i
  end
  
  private
  
  def end_time_after_start_time
    return if end_time.nil?
    if end_time <= start_time
      errors.add(:end_time, "harus setelah waktu mulai")
    end
  end
end
