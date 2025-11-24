class EkgMarker < ApplicationRecord
  belongs_to :recording
  belongs_to :created_by, class_name: 'User', foreign_key: 'created_by_id'
  
  # Medical EKG marker types
  MARKER_TYPES = %w[
    normal
    arrhythmia
    artifact
    annotation
    p_wave
    qrs_complex
    t_wave
    st_segment
    pr_interval
    qt_interval
    atrial_fibrillation
    ventricular_tachycardia
    ventricular_fibrillation
    premature_ventricular_contraction
    premature_atrial_contraction
    bundle_branch_block
    av_block
    sinus_bradycardia
    sinus_tachycardia
    pacemaker_spike
    baseline_wander
    muscle_artifact
    other
  ].freeze
  
  # Validations
  validates :marker_type, presence: true, inclusion: { in: MARKER_TYPES }
  validates :batch_sequence, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :sample_index_start, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :sample_index_end, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :timestamp_start, presence: true
  validates :timestamp_end, presence: true
  validates :severity, inclusion: { in: %w[low medium high critical] }
  validate :end_after_start
  validate :end_index_after_start_index
  
  # Scopes
  scope :ordered, -> { order(:timestamp_start) }
  scope :by_type, ->(type) { where(marker_type: type) }
  scope :by_severity, ->(severity) { where(severity: severity) }
  scope :critical, -> { where(severity: 'critical') }
  scope :high_priority, -> { where(severity: ['high', 'critical']) }
  scope :for_recording, ->(recording_id) { where(recording_id: recording_id) }
  scope :in_batch, ->(batch_sequence) { where(batch_sequence: batch_sequence) }
  
  # Calculate duration in seconds
  def duration_seconds
    return 0 unless timestamp_start && timestamp_end
    (timestamp_end - timestamp_start).to_f
  end
  
  # Calculate duration in milliseconds
  def duration_ms
    (duration_seconds * 1000).round(2)
  end
  
  # Get global sample index (across all batches)
  def global_sample_start
    (batch_sequence * 5000) + sample_index_start
  end
  
  def global_sample_end
    (batch_sequence * 5000) + sample_index_end
  end
  
  # Get number of samples in this marker
  def sample_count
    sample_index_end - sample_index_start + 1
  end
  
  # Check if marker overlaps with another
  def overlaps_with?(other_marker)
    return false unless batch_sequence == other_marker.batch_sequence
    
    (sample_index_start <= other_marker.sample_index_end) &&
    (sample_index_end >= other_marker.sample_index_start)
  end
  
  # Get color based on severity
  def color
    case severity
    when 'low' then '#22c55e'
    when 'medium' then '#fbbf24'
    when 'high' then '#f97316'
    when 'critical' then '#ef4444'
    else '#22c55e'
    end
  end
  
  # Serialize for API response
  def as_json(options = {})
    super(options).merge(
      'created_by_name' => created_by&.name,
      'duration_ms' => duration_ms,
      'sample_count' => sample_count,
      'color' => color
    )
  end
  
  private
  
  def end_after_start
    return unless timestamp_start && timestamp_end
    
    if timestamp_end <= timestamp_start
      errors.add(:timestamp_end, 'must be after timestamp_start')
    end
  end
  
  def end_index_after_start_index
    if sample_index_end <= sample_index_start
      errors.add(:sample_index_end, 'must be greater than sample_index_start')
    end
  end
end
