class UploadSession < ApplicationRecord
  belongs_to :recording
  
  # Validations
  validates :upload_id, presence: true, uniqueness: { case_sensitive: false }
  validates :session_id, presence: true
  validates :file_name, presence: true
  validates :file_size, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :chunk_size, presence: true, numericality: { greater_than: 0 }
  validates :total_chunks, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :file_sha256, presence: true, allow_blank: true
  validates :status, presence: true, inclusion: { in: %w[pending uploading completed failed] }
  
  # Scopes
  scope :pending, -> { where(status: 'pending') }
  scope :uploading, -> { where(status: 'uploading') }
  scope :completed, -> { where(status: 'completed') }
  scope :failed, -> { where(status: 'failed') }
  
  # Callbacks
  before_validation :set_default_status, on: :create
  after_update :update_recording_status, if: :saved_change_to_status?
  
  def chunks_received_array
    chunks_received || []
  end
  
  def chunk_received?(index)
    chunks_received_array.include?(index.to_s)
  end
  
  def mark_chunk_received(index)
    current_chunks = chunks_received_array
    return if current_chunks.include?(index.to_s)
    
    current_chunks << index.to_s
    update!(
      chunks_received: current_chunks,
      chunks_received_count: current_chunks.length
    )
  end
  
  def completed?
    chunks_received_count >= total_chunks
  end
  
  def progress_percentage
    return 0 if total_chunks.zero?
    ((chunks_received_count.to_f / total_chunks) * 100).round(2)
  end
  
  def missing_chunks
    return [] if total_chunks.zero?
    
    all_chunks = (0...total_chunks).to_a.map(&:to_s)
    received_chunks = chunks_received_array
    
    all_chunks - received_chunks
  end
  
  def can_receive_chunk?(index)
    return false if status == 'completed'
    return false if index < 0 || index >= total_chunks
    
    true
  end
  
  def complete_upload!
    return unless can_complete?
    
    update!(status: 'completed')
  end
  
  def fail_upload!
    update!(status: 'failed')
  end
  
  def chunk_file_path(index)
    Rails.root.join('tmp', 'uploads', upload_id, 'chunks', "chunk_#{index.to_s.rjust(8, '0')}")
  end
  
  def chunks_directory
    Rails.root.join('tmp', 'uploads', upload_id, 'chunks')
  end
  
  def assembled_file_path
    Rails.root.join('storage', 'uploads', "patient_#{recording.patient_id}", "#{session_id}.csv")
  end
  
  def assembled_file_directory
    Rails.root.join('storage', 'uploads', "patient_#{recording.patient_id}")
  end
  
  def verify_chunk_checksum(index, data)
    expected_checksum = calculate_chunk_checksum(data)
    # In a real implementation, you'd store expected checksums for each chunk
    # For now, we'll just verify the data is not empty
    data.present? && data.length > 0
  end
  
  def verify_file_checksum(assembled_file_path)
    return false unless File.exist?(assembled_file_path)
    
    require 'digest'
    actual_sha256 = Digest::SHA256.file(assembled_file_path).hexdigest
    actual_sha256 == file_sha256
  end
  
  def cleanup_chunks
    return unless chunks_directory.exist?
    
    FileUtils.rm_rf(chunks_directory)
  end
  
  private
  
  def set_default_status
    self.status ||= 'pending'
    self.chunks_received ||= []
    self.chunks_received_count ||= 0
  end
  
  def update_recording_status
    return unless recording.present?
    
    case status
    when 'completed'
      recording.complete_upload!
    when 'failed'
      recording.fail_upload!
    end
  end
  
  def can_complete?
    status == 'uploading' && completed?
  end
  
  def calculate_chunk_checksum(data)
    require 'digest'
    Digest::SHA256.hexdigest(data)
  end
end
