class BiopotentialSample < ApplicationRecord
  belongs_to :recording
  
  # Validations
  validates :timestamp, presence: true
  validates :sample_value, presence: true, numericality: { only_integer: true }
  validates :sequence_number, presence: true, numericality: { only_integer: true }
  
  # Scopes
  scope :ordered, -> { order(:sequence_number) }
  scope :by_time_range, ->(start_time, end_time) { where(timestamp: start_time..end_time) }
  scope :recent, -> { order(created_at: :desc) }
  
  # Indexes (should be added in migration)
  # add_index :biopotential_samples, [:recording_id, :timestamp]
  # add_index :biopotential_samples, [:recording_id, :sequence_number]
  
  def formatted_timestamp
    timestamp.strftime('%Y-%m-%d %H:%M:%S.%L')
  end
  
  def to_csv_row
    [formatted_timestamp, sample_value]
  end
  
  def self.to_csv_header
    ['timestamp', 'sample_value']
  end
  
  def self.average_sample_value(recording_id, start_time = nil, end_time = nil)
    query = where(recording_id: recording_id)
    query = query.by_time_range(start_time, end_time) if start_time && end_time
    query.average(:sample_value)
  end
  
  def self.min_sample_value(recording_id, start_time = nil, end_time = nil)
    query = where(recording_id: recording_id)
    query = query.by_time_range(start_time, end_time) if start_time && end_time
    query.minimum(:sample_value)
  end
  
  def self.max_sample_value(recording_id, start_time = nil, end_time = nil)
    query = where(recording_id: recording_id)
    query = query.by_time_range(start_time, end_time) if start_time && end_time
    query.maximum(:sample_value)
  end
  
  def self.sample_count(recording_id, start_time = nil, end_time = nil)
    query = where(recording_id: recording_id)
    query = query.by_time_range(start_time, end_time) if start_time && end_time
    query.count
  end
  
  def self.bulk_insert_from_csv(recording_id, csv_data)
    samples_to_insert = []
    sequence = 0
    
    csv_data.each do |row|
      samples_to_insert << {
        recording_id: recording_id,
        timestamp: Time.zone.parse(row['timestamp']),
        sample_value: row['sample_value'].to_i,
        sequence_number: sequence,
        created_at: Time.current,
        updated_at: Time.current
      }
      sequence += 1
      
      # Bulk insert every 10,000 rows to avoid memory issues
      if samples_to_insert.size >= 10_000
        insert_all(samples_to_insert)
        samples_to_insert.clear
      end
    end
    
    # Insert remaining samples
    insert_all(samples_to_insert) if samples_to_insert.any?
    
    sequence
  end
  
  def self.downsample_data(recording_id, factor = 10)
    where(recording_id: recording_id)
      .where('sequence_number % ? = 0', factor)
      .ordered
  end
end
