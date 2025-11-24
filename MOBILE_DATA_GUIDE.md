# 📱 FORMAT DATA DARI MOBILE APP KE SERVER

## Overview
Dokumen ini menjelaskan format data yang diharapkan dari aplikasi mobile pasien untuk sistem EKG.

---

## 🚀 1. START RECORDING

### Endpoint
```
POST /api/recordings/start
```

### Kapan?
Setelah scan QR code dan validasi berhasil

### Request Body
```json
{
  "qr_code": "{\"session_id\":\"702664379c264e04\",\"patient_identifier\":\"f2wkYtlhVFGF\",\"timestamp\":\"2025-11-22T02:13:51Z\",\"expiry\":\"2025-11-23T02:13:51Z\",\"device_type\":\"CardioGuardian\",\"validation_code\":\"60d338770c1c4cb677404b8063dd9234\",\"max_duration_seconds\":3600,\"code\":\"QR_CODE_STRING\"}",
  "session_id": "702664379c264e04",
  "device_id": "CG-12345",
  "device_name": "CardioGuardian #1",
  "sample_rate": 500.0
}
```

### Response
```json
{
  "success": true,
  "message": "Recording dimulai",
  "data": {
    "recording_id": 1,
    "session_id": "702664379c264e04",
    "patient": {
      "id": 5,
      "name": "John Doe",
      "patient_identifier": "f2wkYtlhVFGF"
    },
    "max_duration_seconds": 3600,
    "sample_rate": 500.0,
    "started_at": "2025-11-22T10:30:00.000Z"
  }
}
```

**PENTING:** Simpan `recording_id` untuk digunakan di request berikutnya!

---

## 📊 2. SEND BATCH DATA (SETIAP 10 DETIK)

### Endpoint
```
POST /api/recordings/data
```

### Frekuensi
**Kirim setiap 10 detik** (bukan per 1 detik lagi!)

### Kalkulasi
- Sample rate: **500 Hz** (500 samples per detik)
- Duration: **10 detik**
- Total samples per batch: **5,000 samples**

### Request Body
```json
{
  "recording_id": 1,
  "batch_data": {
    "batch_sequence": 0,
    "start_timestamp": "2025-11-22T10:30:00.000Z",
    "end_timestamp": "2025-11-22T10:30:10.000Z",
    "sample_rate": 500.0,
    "samples": [
      512, 515, 518, 520, 523, 525, 528, 530, 533, 535,
      538, 540, 543, 545, 548, 550, 553, 555, 558, 560,
      ... (5000 values total)
    ]
  }
}
```

### Field Explanation

| Field | Type | Description | Example |
|-------|------|-------------|---------|
| `recording_id` | Integer | ID dari response start recording | `1` |
| `batch_sequence` | Integer | Urutan batch, mulai dari 0 | `0, 1, 2, 3...` |
| `start_timestamp` | String (ISO 8601) | Waktu sample pertama | `2025-11-22T10:30:00.000Z` |
| `end_timestamp` | String (ISO 8601) | Waktu sample terakhir | `2025-11-22T10:30:10.000Z` |
| `sample_rate` | Float | Sampling rate (Hz) | `500.0` |
| `samples` | Array[Integer] | Array 5000 nilai ADC | `[512, 515, ...]` |

### Sample Values
- **Type:** Integer
- **Range:** 0 - 4095 (12-bit ADC)
- **Count:** Exactly 5,000 per batch
- **Unit:** ADC units (akan dikonversi ke mV/µV di frontend)

### Response Success
```json
{
  "success": true,
  "message": "Batch data berhasil disimpan",
  "data": {
    "recording_id": 1,
    "batch_sequence": 0,
    "samples_received": 5000,
    "total_batches": 1,
    "total_samples": 5000
  }
}
```

### Response Error (400)
```json
{
  "success": false,
  "error": "Terlalu banyak samples, max 10,000 per request (received: 15000)"
}
```

### Response Error (422)
```json
{
  "success": false,
  "error": "Recording tidak dalam status recording",
  "current_status": "completed"
}
```

---

## 🛑 3. STOP RECORDING

### Endpoint
```
POST /api/recordings/:id/stop
```

### Kapan?
- User klik tombol stop
- Max duration tercapai
- Error terjadi

### Request
```
POST /api/recordings/1/stop
Body: {} (empty atau kosong)
```

### Response
```json
{
  "success": true,
  "message": "Recording selesai",
  "data": {
    "recording_id": 1,
    "session_id": "702664379c264e04",
    "status": "completed",
    "started_at": "2025-11-22T10:30:00.000Z",
    "ended_at": "2025-11-22T11:30:00.000Z",
    "duration_seconds": 3600,
    "total_samples": 1800000
  }
}
```

---

## 📅 4. COMPLETE FLOW (1 JAM RECORDING)

### Timeline

| Time | Action | Batch # | Samples | Range |
|------|--------|---------|---------|-------|
| 10:30:00 | START | - | - | Start recording |
| 10:30:10 | SEND | 0 | 5,000 | 10:30:00 - 10:30:10 |
| 10:30:20 | SEND | 1 | 5,000 | 10:30:10 - 10:30:20 |
| 10:30:30 | SEND | 2 | 5,000 | 10:30:20 - 10:30:30 |
| ... | ... | ... | ... | ... |
| 11:29:50 | SEND | 359 | 5,000 | 11:29:50 - 11:30:00 |
| 11:30:00 | STOP | - | - | Total: 1,800,000 samples |

**Total untuk 1 jam:**
- Batches: **360** (3600 seconds / 10 seconds)
- Samples: **1,800,000** (360 × 5,000)
- Requests: **362** (1 start + 360 batches + 1 stop)

---

## ✅ 5. DATA VALIDATION

### Sample Values
```
✅ Valid: 512, 0, 4095, 2048
❌ Invalid: -1, 5000, "string", null, undefined
```

### Sample Count
```
✅ Expected: 5000 per batch
⚠️ Acceptable: 4990 - 5010 (with tolerance)
❌ Invalid: < 4990 or > 10,000
```

### Batch Sequence
```
✅ Valid: 0, 1, 2, 3, 4, ...
❌ Invalid: 0, 1, 3, 5 (gap tidak boleh)
❌ Invalid: 0, 0, 1, 2 (duplicate tidak boleh)
```

### Timestamps
```
✅ Format: ISO 8601 UTC
✅ Example: "2025-11-22T10:30:00.000Z"
✅ Precision: Milliseconds
❌ Invalid: "2025-11-22 10:30:00"
❌ Invalid: Timezone bukan UTC
```

### Sample Rate
```
✅ Standard: 500.0 Hz
✅ Alternatives: 250.0, 1000.0
❌ Invalid: Berubah-ubah selama recording
```

---

## 🔧 6. ERROR HANDLING

### Network Failure
```
Scenario: Request timeout / no internet
Action: Store batch locally, retry with exponential backoff
Max retries: 3
Retry delays: 1s, 2s, 4s
```

### Server Error (500)
```
Scenario: Server internal error
Action: Retry after 5 seconds
Max attempts: 3
User message: "Server error, retrying..."
```

### Validation Error (422)
```
Scenario: Invalid data format
Action: Log error, notify user, STOP recording
User message: "Data error, please restart recording"
```

### Recording Not Found (404)
```
Scenario: Recording ID invalid/expired
Action: Restart from QR scan
User message: "Session expired, scan QR again"
```

---

## 🚀 7. MOBILE APP IMPLEMENTATION

### Pseudocode

```javascript
// STEP 1: Initialize
scanQRCode() -> qrData
validateQR(qrData) -> sessionValid
if (sessionValid) {
  startRecording(qrData) -> recordingId
  initializeSensorBuffer(size: 5000)
  startTimer(interval: 10_seconds)
}

// STEP 2: Collect Data
onSensorData(value) {
  buffer.append(value)
  
  if (buffer.length >= 5000) {
    sendBatch(buffer)
    buffer.clear()
  }
}

// STEP 3: Send Batch
sendBatch(samples) {
  batchData = {
    batch_sequence: currentBatchNumber,
    start_timestamp: batchStartTime.toISOString(),
    end_timestamp: getCurrentTime().toISOString(),
    sample_rate: 500.0,
    samples: samples
  }
  
  response = POST('/api/recordings/data', {
    recording_id: recordingId,
    batch_data: batchData
  })
  
  if (response.success) {
    currentBatchNumber++
    batchStartTime = getCurrentTime()
  } else {
    retryBatch(batchData)
  }
}

// STEP 4: Stop
stopRecording() {
  stopSensor()
  stopTimer()
  
  // Send remaining samples if any
  if (buffer.length > 0) {
    sendBatch(buffer)
  }
  
  POST('/api/recordings/' + recordingId + '/stop')
  cleanup()
}
```

---

## 📊 8. DATA SIZE ESTIMATE

| Duration | Batches | Samples | Size (Raw) | Size (Compressed) |
|----------|---------|---------|------------|-------------------|
| 10 sec | 1 | 5,000 | ~20 KB | ~10 KB |
| 1 min | 6 | 30,000 | ~120 KB | ~60 KB |
| 10 min | 60 | 300,000 | ~1.2 MB | ~600 KB |
| 1 hour | 360 | 1,800,000 | ~7.2 MB | ~3-4 MB |

**Recommendation:** Use gzip compression untuk save bandwidth

---

## 🧪 9. TESTING

### Minimal Test (1 Batch)
```bash
curl -X POST http://localhost:3000/api/recordings/data \
  -H "Content-Type: application/json" \
  -d '{
    "recording_id": 1,
    "batch_data": {
      "batch_sequence": 0,
      "start_timestamp": "2025-11-22T10:00:00.000Z",
      "end_timestamp": "2025-11-22T10:00:10.000Z",
      "sample_rate": 500.0,
      "samples": [512, 515, 518, 520, 523]
    }
  }'
```

### Generate Test Data (Python)
```python
import random
import json

def generate_ekg_batch(batch_num):
    samples = []
    for i in range(5000):
        # Simulate normal EKG pattern
        baseline = 512
        noise = random.randint(-10, 10)
        value = baseline + noise
        samples.append(value)
    
    return {
        "batch_sequence": batch_num,
        "samples": samples
    }
```

---

## 📌 SUMMARY / CHECKLIST

### ✅ Format Data yang HARUS Diikuti:

- [x] Kirim data **setiap 10 detik** (bukan per 1 detik)
- [x] Setiap batch = **5,000 samples**
- [x] Format: **JSON** dengan array integer
- [x] Sample values: **0-4095** (12-bit ADC)
- [x] Batch sequence: **Sequential** (0, 1, 2, ...)
- [x] Timestamps: **ISO 8601 UTC format**
- [x] Handle error dengan **retry mechanism**
- [x] **Compress** data untuk save bandwidth
- [x] Stop = kirim **sisa samples** + call stop endpoint

### 🔗 Endpoints:
```
POST /api/recordings/start       → Get recording_id
POST /api/recordings/data         → Send batch (every 10s)
POST /api/recordings/:id/stop     → Complete recording
```

### 📦 Sample Request (Copy-Paste Ready):
```json
{
  "recording_id": 1,
  "batch_data": {
    "batch_sequence": 0,
    "start_timestamp": "2025-11-22T10:30:00.000Z",
    "end_timestamp": "2025-11-22T10:30:10.000Z",
    "sample_rate": 500.0,
    "samples": [512, 515, 518, 520, 523, ...]
  }
}
```

---

## ❓ FAQ

**Q: Kenapa 10 detik bukan 1 detik?**  
A: Lebih efisien! 1 request per 10s vs 10 requests per 10s. Save battery & bandwidth.

**Q: Kalau samples < 5000 gimana?**  
A: Acceptable, tapi ideal 5000. Min 4990, max 10000.

**Q: Kalau network error di tengah recording?**  
A: Store batch locally, retry max 3x, lalu lanjut batch berikutnya.

**Q: Sample rate bisa berubah?**  
A: Tidak! Harus konsisten 500.0 selama recording.

**Q: Format timestamp harus exact ISO 8601?**  
A: Ya! Must include 'Z' suffix (UTC). Contoh: `2025-11-22T10:30:00.000Z`

---

**File JSON contoh:** `MOBILE_DATA_FORMAT.json`  
**Migration status:** ✅ Completed  
**Ready to integrate!** 🚀
