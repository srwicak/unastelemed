"""
Pan-Tompkins QRS Detection Algorithm

Implements the classic Pan-Tompkins algorithm for R-peak detection in ECG signals.

Reference:
Pan, J., & Tompkins, W. J. (1985). A Real-Time QRS Detection Algorithm.
IEEE Transactions on Biomedical Engineering, BME-32(3), 230-236.

Algorithm Steps:
1. Band-pass filter (5-15 Hz)
2. Derivative filter
3. Squaring
4. Moving window integration
5. Adaptive thresholding
"""

import numpy as np
from scipy import signal as scipy_signal


class QRSDetector:
    """
    Pan-Tompkins QRS Detection
    
    Detects R-peaks in ECG signal, which are used for:
    - RR interval calculation
    - Heart rate computation
    - HRV analysis
    """
    
    def __init__(self, sample_rate=250):
        self.sample_rate = sample_rate
        
    def bandpass_filter(self, signal, lowcut=5, highcut=15):
        """
        Band-pass filter to isolate QRS frequencies
        
        The QRS complex has energy mainly in 5-15 Hz range.
        This filter removes baseline wander and high-frequency noise.
        """
        nyquist = self.sample_rate / 2
        low = lowcut / nyquist
        high = highcut / nyquist
        
        # Butterworth band-pass filter
        b, a = scipy_signal.butter(2, [low, high], btype='band')
        filtered = scipy_signal.filtfilt(b, a, signal)
        
        return filtered
    
    def derivative_filter(self, signal):
        """
        5-point derivative filter to emphasize slope
        
        Highlights rapid changes in the signal (QRS upstroke/downstroke)
        """
        # 5-point derivative: H(z) = (1/8T)(-z^-2 - 2z^-1 + 2z + z^2)
        derivative = np.zeros_like(signal)
        for i in range(2, len(signal) - 2):
            derivative[i] = (-signal[i-2] - 2*signal[i-1] + 2*signal[i+1] + signal[i+2]) / 8
        
        return derivative
    
    def squaring(self, signal):
        """
        Square the signal to amplify QRS and make all positive
        """
        return signal ** 2
    
    def moving_window_integration(self, signal, window_ms=150):
        """
        Moving window integration for QRS duration
        
        Window of ~150ms corresponds to typical QRS width
        """
        window_size = int(window_ms * self.sample_rate / 1000)
        integrated = np.convolve(signal, np.ones(window_size) / window_size, mode='same')
        return integrated
    
    def find_peaks(self, integrated_signal, original_signal, refractory_ms=200):
        """
        Adaptive thresholding to find R-peaks
        
        Uses dual thresholds and learning from signal/noise peaks
        """
        peaks = []
        refractory_samples = int(refractory_ms * self.sample_rate / 1000)
        
        # Initialize thresholds
        spki = np.max(integrated_signal[:2*self.sample_rate]) * 0.25  # Signal peak estimate
        npki = np.mean(integrated_signal[:2*self.sample_rate]) * 0.5  # Noise peak estimate
        threshold1 = npki + 0.25 * (spki - npki)
        threshold2 = 0.5 * threshold1
        
        # Find local maxima
        local_max_indices = []
        for i in range(1, len(integrated_signal) - 1):
            if integrated_signal[i] > integrated_signal[i-1] and \
               integrated_signal[i] > integrated_signal[i+1]:
                local_max_indices.append(i)
        
        last_peak_idx = -refractory_samples
        
        for idx in local_max_indices:
            # Refractory period check
            if idx - last_peak_idx < refractory_samples:
                continue
            
            peak_val = integrated_signal[idx]
            
            if peak_val > threshold1:
                # This is a QRS complex
                peaks.append(idx)
                last_peak_idx = idx
                
                # Update signal peak estimate
                spki = 0.125 * peak_val + 0.875 * spki
            elif peak_val > threshold2:
                # Search back for missed peak
                # This handles the case where a QRS was classified as noise
                if len(peaks) > 0:
                    search_start = peaks[-1] + refractory_samples
                    if search_start < idx:
                        # Look for peaks in searchback interval
                        searchback = integrated_signal[search_start:idx]
                        if len(searchback) > 0 and np.max(searchback) > threshold2:
                            sb_idx = np.argmax(searchback) + search_start
                            if sb_idx - last_peak_idx >= refractory_samples:
                                peaks.append(sb_idx)
                                spki = 0.25 * integrated_signal[sb_idx] + 0.75 * spki
                
                # Update noise peak estimate
                npki = 0.125 * peak_val + 0.875 * npki
            else:
                # This is noise
                npki = 0.125 * peak_val + 0.875 * npki
            
            # Update thresholds
            threshold1 = npki + 0.25 * (spki - npki)
            threshold2 = 0.5 * threshold1
        
        peaks.sort()
        return np.array(peaks)
    
    def refine_peaks(self, peaks, original_signal, search_window_ms=50):
        """
        Refine peak locations using original signal
        
        The integrated signal peaks may not align exactly with R-peaks.
        Search in a small window to find the actual maximum.
        """
        search_window = int(search_window_ms * self.sample_rate / 1000)
        refined_peaks = []
        
        for peak in peaks:
            start = max(0, peak - search_window)
            end = min(len(original_signal), peak + search_window)
            
            # Find the actual R-peak (maximum in the window)
            window = original_signal[start:end]
            refined_idx = start + np.argmax(np.abs(window))
            refined_peaks.append(refined_idx)
        
        return np.array(refined_peaks)
    
    def detect(self, signal):
        """
        Main QRS detection function
        
        Args:
            signal: Raw ECG signal
            
        Returns:
            r_peaks: Array of R-peak sample indices
        """
        # Ensure numpy array
        signal = np.array(signal, dtype=np.float64)
        
        # Step 1: Band-pass filter
        filtered = self.bandpass_filter(signal)
        
        # Step 2: Derivative
        derivative = self.derivative_filter(filtered)
        
        # Step 3: Squaring
        squared = self.squaring(derivative)
        
        # Step 4: Moving window integration
        integrated = self.moving_window_integration(squared)
        
        # Step 5: Adaptive thresholding
        peaks = self.find_peaks(integrated, signal)
        
        # Step 6: Refine peaks
        r_peaks = self.refine_peaks(peaks, signal)
        
        return r_peaks


def detect_qrs(signal, sample_rate=250):
    """Convenience function for QRS detection"""
    detector = QRSDetector(sample_rate)
    return detector.detect(signal)
