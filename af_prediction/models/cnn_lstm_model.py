"""
CNN-LSTM Model for AF Detection

This module provides the model architecture and inference functions
for Atrial Fibrillation detection from single-channel ECG signals.

Architecture based on:
1. "Atrial Fibrillation Detection from Holter ECG Using Hybrid CNN-LSTM" (2024)
2. "CNN-LSTM-SE Algorithm for Arrhythmia Classification" (2024)

Training Dataset: MIT-BIH Atrial Fibrillation Database (PhysioNet)
"""

import os
import numpy as np
from scipy import signal as scipy_signal
import tensorflow as tf
from tensorflow import keras

# Model configuration
MODEL_SAMPLE_RATE = 250  # Model was trained at 250Hz
WINDOW_SIZE = 2500       # 10 seconds
MODEL_PATH = os.path.join(
    os.path.dirname(__file__), 
    'trained', 
    'af_cnn_lstm.keras'
)


class AFPredictor:
    """
    AF Prediction using trained CNN-LSTM model
    
    Features:
    - Automatic resampling from device sample rate to model rate
    - Sliding window with overlap for continuous prediction
    - Confidence scores per window
    - AF event aggregation
    """
    
    def __init__(self, model_path=None):
        if model_path is None:
            # Try to load .h5 first (more compatible), then .keras
            base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
            h5_path = os.path.join(base_dir, 'models', 'trained', 'af_cnn_lstm.h5')
            keras_path = os.path.join(base_dir, 'models', 'trained', 'af_cnn_lstm.keras')
            
            if os.path.exists(h5_path):
                self.model_path = h5_path
                print(f"[INFO] Loading model from: {self.model_path} (H5 Legacy Format)")
            else:
                self.model_path = keras_path
                print(f"[INFO] Loading model from: {self.model_path}")
        else:
            self.model_path = model_path

        try:
            # Explicitly compile=False to avoid optimizer version conflicts
            self.model = keras.models.load_model(self.model_path, compile=False)
            print("[INFO] Model loaded successfully.")
        except Exception as e:
            print(f"[ERROR] Failed to load model: {e}")
            raise e
    
    def preprocess_signal(self, samples, sample_rate=400):
        """
        Preprocess raw ECG signal
        
        Args:
            samples: List or array of ECG values
            sample_rate: Sample rate of input signal (Hz)
            
        Returns:
            Preprocessed signal resampled to 250Hz
        """
        signal = np.array(samples, dtype=np.float32)
        
        # Remove NaN/Inf
        signal = np.nan_to_num(signal, nan=0.0, posinf=0.0, neginf=0.0)
        
        # Resample if needed (from device rate to model rate)
        if sample_rate != MODEL_SAMPLE_RATE:
            num_samples = int(len(signal) * MODEL_SAMPLE_RATE / sample_rate)
            signal = scipy_signal.resample(signal, num_samples)
        
        # Normalize to [-1, 1]
        signal_max = np.max(np.abs(signal))
        if signal_max > 0:
            signal = signal / signal_max
        
        return signal
    
    def create_windows(self, signal, window_size=WINDOW_SIZE, overlap=0.5):
        """
        Create overlapping windows from signal
        
        Args:
            signal: Preprocessed ECG signal
            window_size: Window size in samples
            overlap: Overlap ratio (0.5 = 50%)
            
        Returns:
            windows: Array of shape (n_windows, window_size, 1)
            window_positions: List of (start_sample, end_sample) for each window
        """
        step_size = int(window_size * (1 - overlap))
        windows = []
        positions = []
        
        for start in range(0, len(signal) - window_size + 1, step_size):
            end = start + window_size
            window = signal[start:end]
            windows.append(window.reshape(-1, 1))
            positions.append((start, end))
        
        return np.array(windows), positions
    
    def predict_windows(self, windows):
        """
        Predict AF probability for each window
        
        Returns:
            Array of AF probabilities (0-1) for each window
        """
        if self.model is None:
            raise ValueError("Model not loaded")
        
        predictions = self.model.predict(windows, verbose=0)
        return predictions.flatten()
    
    def aggregate_predictions(self, probabilities, positions, 
                             threshold=0.5, min_duration_seconds=5):
        """
        Aggregate window predictions into AF events
        
        Args:
            probabilities: AF probability per window
            positions: (start, end) sample positions
            threshold: Probability threshold for AF classification
            min_duration_seconds: Minimum AF episode duration
            
        Returns:
            List of AF events with start/end times and confidence
        """
        min_samples = min_duration_seconds * MODEL_SAMPLE_RATE
        
        af_events = []
        current_event = None
        
        for i, (prob, (start, end)) in enumerate(zip(probabilities, positions)):
            is_af = prob >= threshold
            
            if is_af:
                if current_event is None:
                    # Start new event
                    current_event = {
                        'start_sample': start,
                        'end_sample': end,
                        'probabilities': [prob]
                    }
                else:
                    # Extend current event
                    current_event['end_sample'] = end
                    current_event['probabilities'].append(prob)
            else:
                if current_event is not None:
                    # End current event
                    duration = current_event['end_sample'] - current_event['start_sample']
                    if duration >= min_samples:
                        af_events.append({
                            'start_sample': current_event['start_sample'],
                            'end_sample': current_event['end_sample'],
                            'confidence': float(np.mean(current_event['probabilities']))
                        })
                    current_event = None
        
        # Handle event at end of signal
        if current_event is not None:
            duration = current_event['end_sample'] - current_event['start_sample']
            if duration >= min_samples:
                af_events.append({
                    'start_sample': current_event['start_sample'],
                    'end_sample': current_event['end_sample'],
                    'confidence': float(np.mean(current_event['probabilities']))
                })
        
        return af_events
    
    def predict(self, samples, sample_rate=400, threshold=0.5):
        """
        Main prediction function
        
        Args:
            samples: Raw ECG signal
            sample_rate: Device sample rate (Hz)
            threshold: AF probability threshold
            
        Returns:
            Dictionary with AF events and summary
        """
        if self.model is None:
            return {
                'status': 'error',
                'message': 'Model not loaded. Run training first.'
            }
        
        # Preprocess
        signal = self.preprocess_signal(samples, sample_rate)
        
        # Check minimum length (need at least one window)
        if len(signal) < WINDOW_SIZE:
            return {
                'status': 'error',
                'message': f'Signal too short. Need at least {WINDOW_SIZE / MODEL_SAMPLE_RATE} seconds.'
            }
        
        # Create windows
        windows, positions = self.create_windows(signal)
        
        # Predict
        probabilities = self.predict_windows(windows)
        
        # Aggregate into events
        af_events = self.aggregate_predictions(probabilities, positions, threshold)
        
        # Convert to seconds
        total_seconds = len(signal) / MODEL_SAMPLE_RATE
        af_seconds = sum(
            (e['end_sample'] - e['start_sample']) / MODEL_SAMPLE_RATE 
            for e in af_events
        )
        normal_seconds = total_seconds - af_seconds
        
        # Format events
        formatted_events = []
        for event in af_events:
            formatted_events.append({
                'start_seconds': event['start_sample'] / MODEL_SAMPLE_RATE,
                'end_seconds': event['end_sample'] / MODEL_SAMPLE_RATE,
                'duration_seconds': (event['end_sample'] - event['start_sample']) / MODEL_SAMPLE_RATE,
                'confidence': event['confidence']
            })
        
        return {
            'status': 'success',
            'af_detected': len(af_events) > 0,
            'af_events': formatted_events,
            'summary': {
                'total_analyzed_minutes': round(total_seconds / 60, 2),
                'normal_rhythm_minutes': round(normal_seconds / 60, 2),
                'af_minutes': round(af_seconds / 60, 2),
                'af_event_count': len(af_events),
                'af_burden_percent': round(100 * af_seconds / total_seconds, 1) if total_seconds > 0 else 0
            },
            'window_probabilities': probabilities.tolist(),
            'window_positions': positions
        }


# Singleton instance
_predictor = None

def get_predictor():
    """Get or create singleton AFPredictor instance"""
    global _predictor
    if _predictor is None:
        _predictor = AFPredictor()
    return _predictor


def predict_af(samples, sample_rate=400, threshold=0.5):
    """Convenience function for prediction"""
    predictor = get_predictor()
    return predictor.predict(samples, sample_rate, threshold)
