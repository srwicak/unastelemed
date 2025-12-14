"""
Heart Rate Calculator

Calculates heart rate statistics from ECG R-peaks:
- Instantaneous HR at each beat
- Min, Average, Max HR
- HR variability metrics (RMSSD, pNN50)

Reference:
Task Force of ESC and NASPE (1996). Heart rate variability: standards of 
measurement, physiological interpretation and clinical use. Circulation, 93(5).
"""

import numpy as np
from .qrs_detector import QRSDetector


class HeartRateCalculator:
    """
    Calculate heart rate and HRV metrics from ECG
    """
    
    def __init__(self, sample_rate=250):
        self.sample_rate = sample_rate
        self.qrs_detector = QRSDetector(sample_rate)
    
    def calculate_rr_intervals(self, r_peaks):
        """
        Calculate RR intervals in milliseconds
        
        Args:
            r_peaks: Array of R-peak sample indices
            
        Returns:
            rr_intervals: Array of RR intervals in ms
        """
        if len(r_peaks) < 2:
            return np.array([])
        
        # Calculate differences between consecutive R-peaks
        rr_samples = np.diff(r_peaks)
        
        # Convert to milliseconds
        rr_ms = (rr_samples / self.sample_rate) * 1000
        
        return rr_ms
    
    def calculate_heart_rate(self, rr_intervals):
        """
        Calculate heart rate in BPM from RR intervals
        
        HR (bpm) = 60000 / RR (ms)
        
        Args:
            rr_intervals: RR intervals in milliseconds
            
        Returns:
            hr_values: Heart rate for each RR interval
        """
        if len(rr_intervals) == 0:
            return np.array([])
        
        # Avoid division by zero
        valid_rr = rr_intervals[rr_intervals > 0]
        hr_values = 60000 / valid_rr
        
        # Clip to physiological range (30-250 BPM)
        hr_values = np.clip(hr_values, 30, 250)
        
        return hr_values
    
    def calculate_statistics(self, signal):
        """
        Calculate comprehensive HR statistics
        
        Args:
            signal: Raw ECG signal
            
        Returns:
            Dictionary with HR statistics
        """
        # Detect R-peaks
        r_peaks = self.qrs_detector.detect(signal)
        
        if len(r_peaks) < 2:
            return {
                'status': 'error',
                'message': 'Not enough R-peaks detected',
                'r_peak_count': len(r_peaks)
            }
        
        # Calculate RR intervals
        rr_intervals = self.calculate_rr_intervals(r_peaks)
        
        # Calculate heart rates
        hr_values = self.calculate_heart_rate(rr_intervals)
        
        if len(hr_values) == 0:
            return {
                'status': 'error',
                'message': 'Could not calculate heart rate',
                'r_peak_count': len(r_peaks)
            }
        
        # Basic statistics
        hr_min = float(np.min(hr_values))
        hr_max = float(np.max(hr_values))
        hr_avg = float(np.mean(hr_values))
        hr_std = float(np.std(hr_values))
        
        # HRV metrics (time-domain)
        # RMSSD: Root mean square of successive differences
        rr_diff = np.diff(rr_intervals)
        rmssd = float(np.sqrt(np.mean(rr_diff ** 2))) if len(rr_diff) > 0 else 0
        
        # pNN50: Percentage of successive differences > 50ms
        nn50_count = np.sum(np.abs(rr_diff) > 50)
        pnn50 = float(100 * nn50_count / len(rr_diff)) if len(rr_diff) > 0 else 0
        
        # SDNN: Standard deviation of NN intervals
        sdnn = float(np.std(rr_intervals))
        
        # Mean RR
        mean_rr = float(np.mean(rr_intervals))
        
        return {
            'status': 'success',
            'r_peak_count': len(r_peaks),
            'r_peak_indices': r_peaks.tolist(),
            'rr_intervals_ms': rr_intervals.tolist(),
            'heart_rate': {
                'min_bpm': round(hr_min, 1),
                'avg_bpm': round(hr_avg, 1),
                'max_bpm': round(hr_max, 1),
                'std_bpm': round(hr_std, 2)
            },
            'hrv_metrics': {
                'mean_rr_ms': round(mean_rr, 2),
                'sdnn_ms': round(sdnn, 2),
                'rmssd_ms': round(rmssd, 2),
                'pnn50_percent': round(pnn50, 2)
            }
        }


def calculate_heart_rate(signal, sample_rate=250):
    """Convenience function for HR calculation"""
    calculator = HeartRateCalculator(sample_rate)
    return calculator.calculate_statistics(signal)
