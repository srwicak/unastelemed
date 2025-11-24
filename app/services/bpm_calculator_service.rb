class BpmCalculatorService
  def initialize(recording)
    @recording = recording
  end

  def calculate
    # Fetch samples. For very large recordings, we might want to process in chunks
    # or limit to a representative segment (e.g., middle 10 seconds).
    # For now, let's try to use a segment to avoid memory issues.
    
    # Get 10 seconds of data from the middle of the recording
    mid_point = @recording.duration_seconds / 2
    start_time = @recording.start_time + mid_point.seconds
    end_time = start_time + 10.seconds
    
    batches = @recording.biopotential_batches.by_time_range(start_time, end_time)
    samples = batches.flat_map(&:samples)
    
    return 0 if samples.empty?
    
    sample_rate = @recording.sample_rate_hz
    return 0 if sample_rate == 0

    peaks = detect_peaks(samples, sample_rate)
    
    return 0 if peaks.size < 2
    
    # Calculate RR intervals in seconds
    rr_intervals = []
    (0...peaks.size - 1).each do |i|
      interval_samples = peaks[i+1] - peaks[i]
      interval_seconds = interval_samples / sample_rate
      rr_intervals << interval_seconds
    end
    
    avg_rr = rr_intervals.sum / rr_intervals.size
    bpm = 60 / avg_rr
    
    bpm.round
  end

  private

  # A simplified Pan-Tompkins-like peak detector
  def detect_peaks(signal, fs)
    # 1. Simple thresholding for R-peak detection
    # In a real scenario, we would need bandpass filtering, differentiation, squaring, and integration.
    # Here we will assume the signal is relatively clean or just find local maxima above a threshold.
    
    max_val = signal.max
    min_val = signal.min
    threshold = max_val * 0.6 # Arbitrary threshold, 60% of max amplitude
    
    peaks = []
    min_dist = 0.6 * fs # Minimum distance between peaks (assuming max 100 BPM -> 0.6s)
    
    last_peak = -min_dist
    
    signal.each_with_index do |val, i|
      if val > threshold
        # Check if it's a local maximum
        if i > 0 && i < signal.size - 1
          if val > signal[i-1] && val > signal[i+1]
            if i - last_peak > min_dist
              peaks << i
              last_peak = i
            elsif val > signal[last_peak] 
              # If we found a higher peak within the refractory period, replace the previous one
              peaks[-1] = i
              last_peak = i
            end
          end
        end
      end
    end
    
    peaks
  end
end
