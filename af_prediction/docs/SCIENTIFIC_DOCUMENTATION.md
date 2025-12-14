# Scientific Documentation: AF Detection Model

## 1. Atrial Fibrillation Overview

### Definition
Atrial Fibrillation (AF) adalah aritmia jantung yang paling umum, ditandai dengan kontraksi tidak teratur dan sering kali sangat cepat dari atrium (serambi) jantung. Pada AF, impuls listrik yang normalnya berasal dari SA node menjadi kacau, menyebabkan denyut jantung yang tidak teratur.

### Karakteristik ECG pada AF
1. **Tidak adanya gelombang P** yang jelas dan teratur
2. **Garis baseline yang tidak teratur** (fibrillatory waves)
3. **Interval RR yang sangat ireguler** (irregularly irregular)
4. **Respon ventrikel** yang bervariasi

### Epidemiologi
- Prevalensi: 2-4% populasi dewasa
- Meningkat seiring usia
- Faktor risiko stroke meningkat 5x lipat
- Salah satu penyebab utama gagal jantung

---

## 2. Dataset: MIT-BIH Atrial Fibrillation Database

### Sumber
PhysioNet MIT-BIH Atrial Fibrillation Database
- URL: https://physionet.org/content/afdb/1.0.0/
- Free and open access

### Karakteristik Dataset
| Parameter | Nilai |
|-----------|-------|
| Jumlah rekaman | 25 |
| Durasi per rekaman | ~10 jam |
| Total durasi | ~250 jam |
| Sample rate | 250 Hz |
| Resolusi | 12-bit |
| Channels | 2 (digunakan channel 0) |

### Anotasi Ritme
- **AFIB**: Atrial Fibrillation
- **AFL**: Atrial Flutter
- **N**: Normal Sinus Rhythm
- **J**: AV Junctional Rhythm

### Reference
> Goldberger, A. L., et al. (2000). PhysioBank, PhysioToolkit, and PhysioNet: Components of a New Research Resource for Complex Physiologic Signals. *Circulation*, 101(23), e215-e220.

---

## 3. Preprocessing Pipeline

### Steps
1. **Load Signal**: Extract channel 0 (equivalent to Lead II)
2. **Normalize**: Scale to [-1, 1] range
3. **Windowing**: 10-second segments (2500 samples @ 250Hz)
4. **Overlap**: 50% overlap untuk meningkatkan jumlah training samples
5. **Labeling**: 
   - >80% AF dalam window → Label 1 (AF)
   - <20% AF dalam window → Label 0 (Normal)
   - 20-80% → Excluded (ambiguous)

### Data Split
- Training: 80%
- Validation: 10%
- Testing: 10%

---

## 4. Model Architecture: CNN-LSTM

### Design Rationale

#### CNN Component
Convolutional Neural Network (CNN) digunakan untuk:
- **Feature extraction** dari morfologi sinyal ECG
- Mendeteksi pola lokal seperti QRS complex, P-wave abnormalities
- Robust terhadap noise dan baseline wandering

#### LSTM Component
Long Short-Term Memory (LSTM) digunakan untuk:
- Menangkap **temporal dependencies** dalam interval RR
- Memahami pola sekuensial dari irama jantung
- Mendeteksi ketidakteraturan yang karakteristik untuk AF

### Architecture Detail

```
Layer                          Output Shape       Parameters
================================================================
Input                          (2500, 1)          0
----------------------------------------------------------------
Conv1D (32 filters, k=5)       (2500, 32)         192
BatchNormalization             (2500, 32)         128
MaxPooling1D (2)               (1250, 32)         0
----------------------------------------------------------------
Conv1D (64 filters, k=5)       (1250, 64)         10,304
BatchNormalization             (1250, 64)         256
MaxPooling1D (2)               (625, 64)          0
----------------------------------------------------------------
Conv1D (128 filters, k=3)      (625, 128)         24,704
BatchNormalization             (625, 128)         512
MaxPooling1D (2)               (312, 128)         0
----------------------------------------------------------------
LSTM (64 units, seq)           (312, 64)          49,408
LSTM (32 units)                (32,)              12,416
----------------------------------------------------------------
Dense (64 units)               (64,)              2,112
Dropout (0.5)                  (64,)              0
Dense (1, sigmoid)             (1,)               65
================================================================
Total Parameters: ~100,000
Trainable Parameters: ~99,500
```

### Training Configuration
| Parameter | Value |
|-----------|-------|
| Optimizer | Adam |
| Learning Rate | 0.001 (with reduction) |
| Loss Function | Binary Cross-Entropy |
| Batch Size | 32 |
| Epochs | 50 (with early stopping) |
| Class Weights | Inversely proportional |

### Callbacks
- **EarlyStopping**: patience=10, monitor=val_auc
- **ReduceLROnPlateau**: factor=0.5, patience=5
- **ModelCheckpoint**: save best model

---

## 5. Heart Rate Detection: Pan-Tompkins Algorithm

### Reference
> Pan, J., & Tompkins, W. J. (1985). A Real-Time QRS Detection Algorithm. *IEEE Transactions on Biomedical Engineering*, BME-32(3), 230-236.

### Algorithm Steps
1. **Band-pass Filter** (5-15 Hz)
   - Removes baseline wander (<5 Hz)
   - Removes high-frequency noise (>15 Hz)
   
2. **Derivative Filter**
   - Emphasizes rapid changes (QRS slopes)
   
3. **Squaring**
   - Amplifies QRS, makes all values positive
   
4. **Moving Window Integration**
   - Window ~150ms (typical QRS duration)
   
5. **Adaptive Thresholding**
   - Dual thresholds (signal peak, noise peak)
   - Searchback algorithm for missed beats

### HRV Metrics Calculated
| Metric | Description |
|--------|-------------|
| Mean RR | Average RR interval (ms) |
| SDNN | Standard deviation of NN intervals |
| RMSSD | Root mean square of successive differences |
| pNN50 | Percentage of NN50 differences |

---

## 6. Inference Pipeline

### Flow
```
Raw ECG Signal (400Hz)
        ↓
Resample to 250Hz
        ↓
Normalize to [-1, 1]
        ↓
Create 10s windows (50% overlap)
        ↓
CNN-LSTM Prediction per window
        ↓
Aggregate into AF events
        ↓
Calculate Heart Rate
        ↓
Generate Report
```

### AF Event Aggregation
- Consecutive high-probability windows grouped
- Minimum duration: 5 seconds
- Confidence: average probability of constituent windows

---

## 7. Expected Performance

### Target Metrics
| Metric | Target | Typical CNN-LSTM |
|--------|--------|------------------|
| Accuracy | >90% | 92-98% |
| Sensitivity | >85% | 88-95% |
| Specificity | >90% | 90-97% |
| AUC-ROC | >0.95 | 0.96-0.99 |

### Limitations
1. Model trained on MIT-BIH database (1975-1979 recordings)
2. May need fine-tuning for modern devices
3. Single channel only
4. Requires minimum 10 seconds of recording

---

## 8. Scientific References

1. **Pan, J., & Tompkins, W. J. (1985)**. A Real-Time QRS Detection Algorithm. *IEEE Transactions on Biomedical Engineering*, BME-32(3), 230-236.

2. **Task Force of ESC and NASPE (1996)**. Heart rate variability: standards of measurement, physiological interpretation and clinical use. *Circulation*, 93(5), 1043-1065.

3. **Goldberger, A. L., et al. (2000)**. PhysioBank, PhysioToolkit, and PhysioNet. *Circulation*, 101(23), e215-e220.

4. **Hindricks, G., et al. (2021)**. 2020 ESC Guidelines for AF. *European Heart Journal*, 42(5), 373-498.

5. **Hybrid CNN-LSTM Papers (2023-2024)**:
   - "Atrial Fibrillation Detection from Holter ECG Using Hybrid CNN-LSTM Model and P/f-wave Identification"
   - "CNN-LSTM-SE Algorithm for Arrhythmia Classification"
   - "Development of a Hybrid Model of CNN and LSTM for Arrhythmia Detection"

6. **Attia, Z. I., et al. (2019)**. An artificial intelligence-enabled ECG algorithm for AF detection. *The Lancet*, 394(10201), 861-867.

---

## 9. Disclaimer

> ⚠️ **PENTING**: Sistem ini adalah alat bantu prediksi berbasis AI dan BUKAN pengganti diagnosis medis profesional. Semua hasil prediksi HARUS dikonfirmasi oleh dokter spesialis jantung sebelum digunakan untuk pengambilan keputusan klinis.
