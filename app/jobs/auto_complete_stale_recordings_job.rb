# frozen_string_literal: true

# Background job to automatically complete recordings that are stuck in 'recording' status
# 
# This job handles cases where:
# - Mobile app crashes before calling /stop
# - Network connection lost
# - Patient emergency (recording interrupted)
# - App force-closed by user
#
# Strategy:
# - Find recordings with status 'recording'
# - Check if last batch received > threshold time ago
# - Auto-complete the recording with existing data
#
# Run frequency: Every 5 minutes (configured in schedule.yml or cron)
class AutoCompleteStaleRecordingsJob < ApplicationJob
  queue_as :default
  
  # Time threshold: if no data received in X minutes, consider recording stale
  STALE_THRESHOLD_MINUTES = 15
  
  # Note: Max duration check is now handled by Recording#exceeded_max_duration?
  # which uses QR code's max_duration + proportional grace period
  
  def perform
    Rails.logger.info "[AutoCompleteStaleRecordings] Starting job..."
    
    # Find stale recordings
    stale_recordings = find_stale_recordings
    
    if stale_recordings.empty?
      Rails.logger.info "[AutoCompleteStaleRecordings] No stale recordings found"
      return
    end
    
    Rails.logger.info "[AutoCompleteStaleRecordings] Found #{stale_recordings.count} stale recordings"
    
    # Process each stale recording
    completed_count = 0
    failed_count = 0
    
    stale_recordings.each do |recording|
      begin
        complete_recording(recording)
        completed_count += 1
        Rails.logger.info "[AutoCompleteStaleRecordings] ✓ Completed recording ##{recording.id}"
      rescue StandardError => e
        failed_count += 1
        Rails.logger.error "[AutoCompleteStaleRecordings] ✗ Failed to complete recording ##{recording.id}: #{e.message}"
      end
    end
    
    Rails.logger.info "[AutoCompleteStaleRecordings] Completed: #{completed_count}, Failed: #{failed_count}"
  end
  
  private
  
  def find_stale_recordings
    Recording.where(status: 'recording').select do |recording|
      is_stale?(recording)
    end
  end
  
  def is_stale?(recording)
    # Use the model's stale? method which includes max_duration + grace period check
    recording.stale?(STALE_THRESHOLD_MINUTES)
  end
  
  def complete_recording(recording)
    # Use the model's force_complete! method which handles end_time intelligently
    reason = if recording.exceeded_max_duration?
      max_duration = recording.qr_code.duration_in_seconds
      grace_period = recording.calculate_grace_period(max_duration)
      "Exceeded max_duration (#{max_duration / 60}m) + grace_period (#{grace_period / 60}m)"
    else
      "No activity in #{STALE_THRESHOLD_MINUTES} minutes"
    end
    
    recording.force_complete!(reason: reason)
    
    Rails.logger.info "[Complete] Recording ##{recording.id} auto-completed: duration=#{recording.duration_seconds}s, samples=#{recording.total_samples}, batches=#{recording.biopotential_batches.count}"
  end
end
