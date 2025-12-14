# frozen_string_literal: true

# Controller for AF (Atrial Fibrillation) Prediction feature
#
# Features:
# - Load existing prediction from database if available
# - Run new prediction and save results
# - Re-predict with confirmation (replaces previous prediction)
#
class AfPredictionsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_recording

  # GET /af_prediction/:session_id
  def show
    # Check for existing prediction first
    @prediction = AfPrediction.latest_for(@recording)

    if @prediction.nil?
      # No existing prediction - run initial prediction
      run_and_save_prediction
    else
      # Load from database
      load_prediction_data
    end
  end

  # POST /af_prediction/:session_id/repredict
  def repredict
    # Delete existing prediction
    old_prediction = AfPrediction.latest_for(@recording)
    old_prediction&.destroy

    # Run new prediction
    run_and_save_prediction

    redirect_to af_prediction_path(@recording.session_id),
                notice: "Prediksi ulang berhasil dilakukan"
  end

  private

  def set_recording
    @recording = Recording.find_by!(session_id: params[:session_id])

    unless can_access_recording?(@recording)
      flash[:alert] = "Anda tidak memiliki akses ke rekaman ini"
      redirect_to dashboard_path
    end
  end

  def can_access_recording?(recording)
    return true if current_user.superuser?
    return true if current_user.hospital_manager?
    return true if current_user.medical_staff
    return true if current_user.patient? && recording.patient == current_user.patient

    false
  end

  def run_and_save_prediction
    # Run AF prediction via service
    result = AfPredictionService.predict(@recording)

    if result[:status] == "error"
      flash[:alert] = result[:message]
      redirect_to view_recording_path(@recording.session_id)
      return
    end

    # Save prediction to database
    @prediction = save_prediction(result)

    # Prepare display data
    load_prediction_data
  end

  def save_prediction(result)
    summary = result[:summary] || {}
    heart_rate = result[:heart_rate] || {}

    AfPrediction.create!(
      recording: @recording,
      predicted_by: current_user,
      af_detected: result[:af_detected] || false,
      af_event_count: summary[:af_event_count] || 0,
      af_burden_percent: summary[:af_burden_percent],
      total_analyzed_minutes: summary[:total_analyzed_minutes],
      normal_rhythm_minutes: summary[:normal_rhythm_minutes],
      af_minutes: summary[:af_minutes],
      hr_min_bpm: heart_rate[:min_bpm],
      hr_avg_bpm: heart_rate[:avg_bpm],
      hr_max_bpm: heart_rate[:max_bpm],
      af_events: result[:af_events] || [],
      summary: summary,
      hrv_metrics: result[:hrv_metrics] || {},
      conclusion: result[:conclusion],
      window_probabilities: result[:window_probabilities] || [],
      status: "completed",
      predicted_at: Time.current
    )
  end

  def load_prediction_data
    @patient = @recording.patient
    @session = @recording.recording_session

    # Build result hash from saved prediction
    @result = {
      status: "success",
      af_detected: @prediction.af_detected,
      af_events: @prediction.formatted_af_events,
      summary: @prediction.summary&.deep_symbolize_keys || {},
      heart_rate: @prediction.heart_rate_summary,
      hrv_metrics: @prediction.formatted_hrv_metrics,
      conclusion: @prediction.conclusion
    }

    # Additional display data
    @window_probs = @prediction.window_probabilities || []
    @af_markers = (@result[:af_events] || []).map do |event|
      {
        start: event[:start_seconds],
        stop: event[:end_seconds],
        confidence: event[:confidence],
        label: "AF #{((event[:confidence] || 0) * 100).round}%"
      }
    end

    @summary = @result[:summary]
    @heart_rate = @result[:heart_rate]
    @hrv_metrics = @result[:hrv_metrics]
    @af_detected = @prediction.af_detected
    @af_count = @prediction.af_event_count || 0
    @af_burden = @prediction.af_burden_percent || 0

    # Prediction metadata
    @predicted_at = @prediction.predicted_at
    @predicted_by = @prediction.predicted_by
  end
end
