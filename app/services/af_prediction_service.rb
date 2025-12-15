# frozen_string_literal: true

# Service for communicating with the AF Prediction Python API
#
# Usage:
#   result = AfPredictionService.predict(recording)
#   result[:status] # => 'success' or 'error'
#   result[:af_events] # => Array of AF events
#   result[:summary] # => Summary statistics
#   result[:heart_rate] # => Heart rate stats
#
class AfPredictionService
  AF_API_URL = ENV.fetch("AF_PREDICTION_API_URL", "http://localhost:5050")
  AF_API_TIMEOUT = ENV.fetch("AF_PREDICTION_TIMEOUT", 60).to_i

  class << self
    def predict(recording)
      # Get samples from biopotential batches
      samples = prepare_samples(recording)

      if samples.empty?
        return {
          status: "error",
          message: "Tidak ada data EKG tersedia untuk recording ini"
        }
      end

      # Get sample rate and ensure it is an integer
      sample_rate = (recording.sample_rate || 400).to_i

      # Make API request
      response = make_request(samples, sample_rate)

      # Parse and return response
      parse_response(response)
    rescue StandardError => e
      Rails.logger.error("AF Prediction Error: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))

      {
        status: "error",
        message: "Gagal melakukan prediksi AF: #{e.message}"
      }
    end

    private

    def prepare_samples(recording)
      samples = []

      # Get all biopotential batches ordered by sequence
      batches = recording.biopotential_batches.ordered

      batches.each do |batch|
        batch_samples = batch.data["samples"]
        samples.concat(batch_samples) if batch_samples.is_a?(Array)
      end

      Rails.logger.info("AF Prediction: Prepared #{samples.size} samples from #{batches.count} batches")

      samples
    end

    def make_request(samples, sample_rate)
      require "net/http"
      require "json"

      uri = URI.parse("#{AF_API_URL}/api/predict-af")

      http = Net::HTTP.new(uri.host, uri.port)
      http.read_timeout = AF_API_TIMEOUT
      http.open_timeout = 10

      request = Net::HTTP::Post.new(uri.path)
      request["Content-Type"] = "application/json"
      request.body = {
        samples: samples,
        sample_rate: sample_rate
      }.to_json

      Rails.logger.info("AF Prediction: Sending #{samples.size} samples to #{AF_API_URL}")

      response = http.request(request)

      unless response.is_a?(Net::HTTPSuccess)
        raise "API returned #{response.code}: #{response.body}"
      end

      JSON.parse(response.body)
    end

    def parse_response(response)
      # Convert string keys to symbols for Ruby convention
      result = response.deep_symbolize_keys

      # Add formatted times for AF events
      if result[:af_events].is_a?(Array)
        result[:af_events] = result[:af_events].map do |event|
          event[:formatted_start] = format_seconds(event[:start_seconds])
          event[:formatted_end] = format_seconds(event[:end_seconds])
          event[:formatted_duration] = format_duration(event[:duration_seconds])
          event
        end
      end

      result
    end

    def format_seconds(seconds)
      return "--:--" unless seconds

      mins = (seconds / 60).to_i
      secs = (seconds % 60).to_i
      format("%02d:%02d", mins, secs)
    end

    def format_duration(seconds)
      return "--" unless seconds

      if seconds < 60
        "#{seconds.to_i} detik"
      else
        mins = (seconds / 60).to_i
        secs = (seconds % 60).to_i
        "#{mins} menit #{secs} detik"
      end
    end
  end
end
