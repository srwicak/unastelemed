"""
AF Prediction API Server

Flask API for Atrial Fibrillation prediction using CNN-LSTM model.

Endpoints:
- GET  /health          - Health check
- POST /api/predict-af  - Predict AF from ECG signal

Usage:
    python app.py
    # API runs on http://localhost:5050
"""

import os
import sys

# FORCE LEGACY KERAS (IMPORTANT for TF 2.16+ loading models from TF 2.15)
# This must be set before importing tensorflow/keras
os.environ["TF_USE_LEGACY_KERAS"] = "1"

from flask import Flask, request, jsonify
from flask_cors import CORS
import numpy as np

# Add parent directory to path for imports
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from models.cnn_lstm_model import AFPredictor, MODEL_SAMPLE_RATE
from models.hr_calculator import HeartRateCalculator
from scipy import signal as scipy_signal

# Initialize Flask app
app = Flask(__name__)
CORS(app)  # Enable CORS for Rails integration

# Initialize models
af_predictor = None
hr_calculator = None


def get_af_predictor():
    """Lazy load AF predictor"""
    global af_predictor
    if af_predictor is None:
        af_predictor = AFPredictor()
    return af_predictor


def get_hr_calculator():
    """Lazy load HR calculator"""
    global hr_calculator
    if hr_calculator is None:
        hr_calculator = HeartRateCalculator(MODEL_SAMPLE_RATE)
    return hr_calculator


@app.route('/health', methods=['GET'])
def health_check():
    """Health check endpoint"""
    predictor = get_af_predictor()
    model_loaded = predictor.model is not None
    
    return jsonify({
        'status': 'healthy',
        'model_loaded': model_loaded,
        'model_sample_rate': MODEL_SAMPLE_RATE,
        'version': '1.0.0'
    })


@app.route('/api/predict-af', methods=['POST'])
def predict_af():
    """
    Predict Atrial Fibrillation from ECG signal
    
    Request body:
    {
        "samples": [array of ECG values],
        "sample_rate": 400  // Device sample rate in Hz
    }
    
    Response:
    {
        "status": "success",
        "af_detected": true,
        "af_events": [...],
        "summary": {...},
        "heart_rate": {...}
    }
    """
    try:
        # Parse request
        data = request.get_json()
        
        if not data:
            return jsonify({
                'status': 'error',
                'message': 'No JSON data provided'
            }), 400
        
        samples = data.get('samples')
        
        # Ensure numeric parameters are safely casted
        try:
            sample_rate = int(data.get('sample_rate', 400))
            threshold = float(data.get('threshold', 0.5))
        except (ValueError, TypeError):
             return jsonify({
                'status': 'error',
                'message': 'Invalid format for sample_rate or threshold (must be numbers)'
            }), 400
        
        if samples is None:
            return jsonify({
                'status': 'error',
                'message': 'Missing required field: samples'
            }), 400
        
        if not isinstance(samples, list) or len(samples) == 0:
            return jsonify({
                'status': 'error',
                'message': 'samples must be a non-empty array'
            }), 400
        
        # Convert to numpy array
        samples_array = np.array(samples, dtype=np.float32)
        
        # Check minimum length (need at least 10 seconds of data)
        min_samples = 10 * sample_rate
        if len(samples_array) < min_samples:
            return jsonify({
                'status': 'error',
                'message': f'Signal too short. Need at least 10 seconds ({min_samples} samples at {sample_rate}Hz)'
            }), 400
        
        # Get predictor and run prediction
        predictor = get_af_predictor()
        af_result = predictor.predict(samples_array, sample_rate, threshold)
        
        if af_result.get('status') == 'error':
            return jsonify(af_result), 500
        
        # Calculate heart rate
        hr_calc = get_hr_calculator()
        
        # Resample signal for HR calculation
        preprocessed = predictor.preprocess_signal(samples_array, sample_rate)
        hr_result = hr_calc.calculate_statistics(preprocessed)
        
        # Combine results
        response = {
            'status': 'success',
            'af_detected': af_result.get('af_detected', False),
            'af_events': af_result.get('af_events', []),
            'summary': af_result.get('summary', {}),
            'heart_rate': hr_result.get('heart_rate', {
                'min_bpm': 0,
                'avg_bpm': 0,
                'max_bpm': 0
            }),
            'hrv_metrics': hr_result.get('hrv_metrics', {}),
            'r_peak_count': hr_result.get('r_peak_count', 0)
        }
        
        # Generate conclusion
        response['conclusion'] = generate_conclusion(response)
        
        return jsonify(response)
        
    except Exception as e:
        import traceback
        return jsonify({
            'status': 'error',
            'message': str(e),
            'traceback': traceback.format_exc()
        }), 500


def generate_conclusion(result):
    """Generate human-readable conclusion in Indonesian"""
    summary = result.get('summary', {})
    hr = result.get('heart_rate', {})
    af_events = result.get('af_events', [])
    
    total_minutes = summary.get('total_analyzed_minutes', 0)
    af_minutes = summary.get('af_minutes', 0)
    af_count = summary.get('af_event_count', 0)
    af_burden = summary.get('af_burden_percent', 0)
    
    hr_min = hr.get('min_bpm', 0)
    hr_avg = hr.get('avg_bpm', 0)
    hr_max = hr.get('max_bpm', 0)
    
    lines = []
    
    # Recording summary
    lines.append(f"📊 Analisis EKG: {total_minutes:.1f} menit data telah dianalisis.")
    
    # AF findings
    if af_count > 0:
        lines.append(f"\n⚠️ TERDETEKSI AF: {af_count} episode Atrial Fibrillation dengan total durasi {af_minutes:.1f} menit ({af_burden:.1f}% dari total rekaman).")
        
        if len(af_events) > 0:
            lines.append("\nDetail episode AF:")
            for i, event in enumerate(af_events[:5], 1):  # Show max 5 events
                start = event.get('start_seconds', 0)
                end = event.get('end_seconds', 0)
                duration = event.get('duration_seconds', 0)
                confidence = event.get('confidence', 0)
                
                # Convert to time format
                start_min = int(start // 60)
                start_sec = int(start % 60)
                end_min = int(end // 60)
                end_sec = int(end % 60)
                
                lines.append(f"  {i}. {start_min:02d}:{start_sec:02d} - {end_min:02d}:{end_sec:02d} (durasi: {duration:.0f} detik, confidence: {confidence:.0%})")
            
            if len(af_events) > 5:
                lines.append(f"  ... dan {len(af_events) - 5} episode lainnya")
    else:
        lines.append("\n✅ TIDAK TERDETEKSI AF: Tidak ditemukan episode Atrial Fibrillation.")
    
    # Heart rate summary
    lines.append(f"\n❤️ Denyut Jantung:")
    lines.append(f"   • Minimum: {hr_min:.0f} BPM")
    lines.append(f"   • Rata-rata: {hr_avg:.0f} BPM")
    lines.append(f"   • Maksimum: {hr_max:.0f} BPM")
    
    # Recommendations
    lines.append("\n📋 CATATAN:")
    lines.append("Hasil ini adalah prediksi AI dan HARUS dikonfirmasi oleh dokter spesialis jantung.")
    
    if af_count > 0:
        lines.append("Disarankan untuk konsultasi lebih lanjut dengan dokter untuk evaluasi dan tatalaksana.")
    
    return '\n'.join(lines)


if __name__ == '__main__':
    # Configuration
    HOST = os.environ.get('AF_API_HOST', '0.0.0.0')
    PORT = int(os.environ.get('AF_API_PORT', 5050))
    DEBUG = os.environ.get('AF_API_DEBUG', 'false').lower() == 'true'
    
    print("=" * 60)
    print("AF Prediction API Server")
    print("=" * 60)
    print(f"Host: {HOST}")
    print(f"Port: {PORT}")
    print(f"Debug: {DEBUG}")
    print("-" * 60)
    
    # Pre-load model
    print("Loading model...")
    predictor = get_af_predictor()
    if predictor.model is not None:
        print("✓ Model loaded successfully")
    else:
        print("⚠ Model not found - run training first")
    
    print("-" * 60)
    print("API Endpoints:")
    print("  GET  /health          - Health check")
    print("  POST /api/predict-af  - Predict AF from ECG")
    print("=" * 60)
    
    app.run(host=HOST, port=PORT, debug=DEBUG)
