class BiopotentialBatch < ApplicationRecord
  belongs_to :recording
  
  # Validations
  validates :start_timestamp, presence: true
  validates :end_timestamp, presence: true
  validates :batch_sequence, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :sample_rate, presence: true, numericality: { greater_than: 0 }
  validates :sample_count, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :data, presence: true
  validate :validate_data_structure
  validate :end_timestamp_after_start_timestamp
  
  # Scopes
  scope :ordered, -> { order(:batch_sequence) }
  # Fixed: Find batches that overlap with the time range (not just those fully contained)
  # A batch overlaps if: batch_start <= range_end AND batch_end >= range_start
  scope :by_time_range, ->(start_time, end_time) { where('start_timestamp <= ? AND end_timestamp >= ?', end_time, start_time) }
  scope :recent, -> { order(created_at: :desc) }
  scope :for_recording, ->(recording_id) { where(recording_id: recording_id) }
  
  # Callbacks
  before_save :calculate_min_max

  # Get all samples as flat array
  def samples
    data['samples'] || []
  end

  # Get sample at specific index
  def sample_at(index)
    samples[index]
  end

  # Calculate duration in seconds
  def duration_seconds
    return 0 unless start_timestamp && end_timestamp
    (end_timestamp - start_timestamp).to_f
  end

  
  # Calculate actual sample rate from data
  def actual_sample_rate
    return 0 if duration_seconds == 0
    (sample_count.to_f / duration_seconds).round(2)
  end
  
  # Get timestamp for specific sample index (interpolated)
  def timestamp_at(index)
    return nil if index >= sample_count || index < 0
    time_offset = (duration_seconds / sample_count) * index
    start_timestamp + time_offset.seconds
  end
  
  # Export batch to CSV format
  def to_csv
    csv_data = []
    samples.each_with_index do |value, index|
      csv_data << [timestamp_at(index).iso8601(3), value]
    end
    csv_data
  end
  
  # Get statistics for this batch
  def statistics
    sample_values = samples
    return {} if sample_values.empty?
    
    {
      min: sample_values.min,
      max: sample_values.max,
      mean: (sample_values.sum.to_f / sample_values.size).round(2),
      median: calculate_median(sample_values),
      sample_count: sample_values.size
    }
  end
  
  # Bulk create batches from array
  def self.bulk_create(recording_id, batches_data)
    batches_to_insert = batches_data.map do |batch|
      {
        recording_id: recording_id,
        start_timestamp: batch[:start_timestamp],
        end_timestamp: batch[:end_timestamp],
        batch_sequence: batch[:batch_sequence],
        sample_rate: batch[:sample_rate],
        sample_count: batch[:sample_count],
        data: { samples: batch[:samples] },
        created_at: Time.current,
        updated_at: Time.current
      }
    end
    
    insert_all(batches_to_insert)
    batches_data.size
  end
  
  # Get time range for this batch
  def time_range
    start_timestamp..end_timestamp
  end
  
  # Check if timestamp falls within this batch
  def includes_time?(timestamp)
    time_range.cover?(timestamp)
  end
  
  # Downsample data (reduce resolution for visualization)
  def downsample(factor = 10)
    return samples if factor <= 1
    samples.each_slice(factor).map { |slice| slice.sum / slice.size }
  end
  
  private
  
  def validate_data_structure
    return if data.blank?
    
    unless data.is_a?(Hash)
      errors.add(:data, 'must be a hash')
      return
    end
    
    unless data['samples'].is_a?(Array)
      errors.add(:data, 'must contain samples array')
      return
    end
    
    if sample_count && data['samples'].size != sample_count
      errors.add(:data, "samples array size (#{data['samples'].size}) doesn't match sample_count (#{sample_count})")
    end
  end
  
  def end_timestamp_after_start_timestamp
    return unless start_timestamp && end_timestamp
    
    if end_timestamp <= start_timestamp
      errors.add(:end_timestamp, 'must be after start_timestamp')
    end
  end
  
  def calculate_median(array)
    sorted = array.sort
    len = sorted.length
    (sorted[(len - 1) / 2] + sorted[len / 2]) / 2.0
  end

  def calculate_min_max
    vals = samples
    return if vals.empty?
    
    self.min_value = vals.min
    self.max_value = vals.max
  end
end
