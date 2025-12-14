# frozen_string_literal: true

# Model for storing AF (Atrial Fibrillation) prediction results
#
# Stores the prediction results from the CNN-LSTM model so that:
# 1. Results can be viewed again without re-running prediction
# 2. Historical predictions are preserved
# 3. Re-prediction requires explicit confirmation
#
class AfPrediction < ApplicationRecord
  belongs_to :recording
  belongs_to :predicted_by, class_name: "User", optional: true

  # Validations
  validates :recording_id, presence: true
  validates :status, presence: true, inclusion: { in: %w[pending processing completed failed] }

  # Scopes
  scope :completed, -> { where(status: "completed") }
  scope :recent, -> { order(predicted_at: :desc) }
  scope :for_recording, ->(recording_id) { where(recording_id: recording_id) }

  # Callbacks
  before_create :set_predicted_at

  # Get the latest prediction for a recording
  def self.latest_for(recording)
    for_recording(recording.id).completed.recent.first
  end

  # Check if this prediction detected AF
  def has_af?
    af_detected == true && af_event_count.to_i > 0
  end

  # Get formatted AF events for display
  def formatted_af_events
    return [] unless af_events.is_a?(Array)

    af_events.map do |event|
      event_sym = event.deep_symbolize_keys
      {
        start_seconds: event_sym[:start_seconds],
        end_seconds: event_sym[:end_seconds],
        duration_seconds: event_sym[:duration_seconds],
        confidence: event_sym[:confidence],
        formatted_start: format_seconds(event_sym[:start_seconds]),
        formatted_end: format_seconds(event_sym[:end_seconds]),
        formatted_duration: format_duration(event_sym[:duration_seconds])
      }
    end
  end

  # Get heart rate summary
  def heart_rate_summary
    {
      min_bpm: hr_min_bpm&.to_f&.round(0) || 0,
      avg_bpm: hr_avg_bpm&.to_f&.round(0) || 0,
      max_bpm: hr_max_bpm&.to_f&.round(0) || 0
    }
  end

  # Get HRV metrics with proper formatting
  def formatted_hrv_metrics
    return {} unless hrv_metrics.is_a?(Hash)

    hrv_metrics.transform_keys(&:to_sym)
  end

  private

  def set_predicted_at
    self.predicted_at ||= Time.current
  end

  def format_seconds(seconds)
    return "--:--" unless seconds

    mins = (seconds.to_f / 60).to_i
    secs = (seconds.to_f % 60).to_i
    format("%02d:%02d", mins, secs)
  end

  def format_duration(seconds)
    return "--" unless seconds

    secs = seconds.to_f
    if secs < 60
      "#{secs.to_i} detik"
    else
      mins = (secs / 60).to_i
      remaining_secs = (secs % 60).to_i
      "#{mins} menit #{remaining_secs} detik"
    end
  end
end
