# AF Prediction API

Sistem prediksi Atrial Fibrillation (AF) menggunakan CNN-LSTM yang di-training dengan MIT-BIH AF Database.

## Setup

```bash
# Create virtual environment
python3 -m venv venv
source venv/bin/activate

# Install dependencies
pip install -r requirements.txt
```

## Training Model

```bash
# 1. Download MIT-BIH AF Database
python training/download_dataset.py

# 2. Preprocess data
python training/preprocess.py

# 3. Train model
python training/train_model.py

# 4. Evaluate
python training/evaluate.py
```

## Running API Server

```bash
source venv/bin/activate
python app.py
# API akan berjalan di http://localhost:5050
```

## Deployment (VPS dengan tmux)

```bash
./deploy.sh
```

## API Endpoints

### POST /api/predict-af

Request:
```json
{
    "samples": [0.1, 0.2, ...],
    "sample_rate": 400
}
```

Response:
```json
{
    "status": "success",
    "af_events": [...],
    "summary": {...},
    "heart_rate": {...}
}
```

### GET /health

Health check endpoint.

## Scientific References

1. Pan & Tompkins (1985) - QRS Detection
2. PhysioNet MIT-BIH AF Database
3. CNN-LSTM for AF Detection (2023-2024 papers)
