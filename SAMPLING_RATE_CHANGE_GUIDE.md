# 📊 Panduan Mengubah Sampling Rate (500 Hz → 400 Hz)

## 🎯 Overview

Dokumen ini menjelaskan **semua tempat** yang perlu diubah untuk mengubah sampling rate dari 500 Hz ke 400 Hz.

---

## ✅ Yang SUDAH Diubah (Rails Backend)

### 1. **Database Seeds** (`db/seeds.rb`)
✅ Default sample_rate: `400.0` Hz  
✅ Samples per batch: `4000` (10 detik × 400 Hz)  
✅ Time calculation: `j / 400.0`  
✅ Total samples: `batch_count * 4000`

**Hasil:** Test data akan generate dengan 400 Hz

### 2. **Test Script** (`tmp/add_sample_batches.rb`)
✅ Default sample_rate: `400.0` Hz  
✅ Samples per batch: `4000`  
✅ Time calculation: `j / 400.0`  

**Hasil:** Manual test script pakai 400 Hz

### 3. **API Controller** (`app/controllers/api/recordings_controller.rb`)
✅ Default fallback di `start` action: `400.0`  
✅ Default fallback di `process_batch_data`: `400.0`

**Hasil:** Jika mobile app TIDAK kirim `sample_rate`, default = 400 Hz

### 4. **View Display** (`app/views/dashboard/view_recording.html.erb`)
✅ Display fallback: `@recording.sample_rate || 400`

**Hasil:** UI akan tampilkan "Sample Rate: 400 Hz" jika data kosong

---

## ⚠️ Yang WAJIB Diubah (Mobile App)

### 📱 Aplikasi Mobile - Batch Data Format

**File:** `lib/services/biopotential_service.dart` (atau sejenisnya)

**BEFORE (500 Hz):**
```dart
final batchData = {
  'batch_sequence': batchSequence,
  'sampling_rate': 500,  // ❌ LAMA
  'start_timestamp': startTime.toIso8601String(),
  'end_timestamp': endTime.toIso8601String(),
  'samples': samples, // Array of 5000 values (10s × 500Hz)
};
```

**AFTER (400 Hz):**
```dart
final batchData = {
  'batch_sequence': batchSequence,
  'sampling_rate': 400,  // ✅ BARU
  'start_timestamp': startTime.toIso8601String(),
  'end_timestamp': endTime.toIso8601String(),
  'samples': samples, // Array of 4000 values (10s × 400Hz)
};
```

**⚡ PENTING:**
- **WAJIB** ubah `sampling_rate` di metadata
- **WAJIB** kirim 4000 samples per batch (bukan 5000)
- Durasi per batch tetap **10 detik**
- Rails akan otomatis simpan value ini ke database

---

## 📐 Perhitungan Sample Count

### Rumus:
```
sample_count = duration_seconds × sampling_rate
```

### Contoh untuk 10 detik:
- **500 Hz:** 10s × 500 = **5000 samples**
- **400 Hz:** 10s × 400 = **4000 samples**

### Contoh untuk 1 menit (60 detik):
- **500 Hz:** 60s × 500 = **30,000 samples**
- **400 Hz:** 60s × 400 = **24,000 samples**

### Contoh untuk 1 jam (3600 detik):
- **500 Hz:** 3600s × 500 = **1,800,000 samples**
- **400 Hz:** 3600s × 400 = **1,440,000 samples**

**Keuntungan 400 Hz:**
- Storage lebih hemat: **20% reduction** (1.8M → 1.44M)
- Network bandwidth lebih kecil
- Processing lebih cepat

---

## 🔄 Alur Data End-to-End

```
┌─────────────────────────────────────────────────────────────┐
│ 1. MOBILE APP (Hardware)                                    │
│    - Sensor ADC collect @ 400 Hz                            │
│    - Buffer 10 detik = 4000 samples                         │
│    - Kirim batch setiap 10 detik                            │
└──────────────────┬──────────────────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────────────────────┐
│ 2. MOBILE APP (Batch Data)                                  │
│    POST /api/recordings/data                                │
│    {                                                         │
│      "recording_id": 123,                                   │
│      "batch_data": {                                        │
│        "batch_sequence": 0,                                 │
│        "sampling_rate": 400,  ◄── CRITICAL!                │
│        "start_timestamp": "2025-11-29T10:00:00.000Z",      │
│        "end_timestamp": "2025-11-29T10:00:10.000Z",        │
│        "samples": [0.123, 0.145, ..., 0.089]  (4000 items) │
│      }                                                       │
│    }                                                         │
└──────────────────┬──────────────────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────────────────────┐
│ 3. RAILS CONTROLLER (process_batch_data)                   │
│    - Parse sample_rate dari request                        │
│    - Fallback ke 400.0 jika tidak ada                      │
│    - Simpan ke BiopotentialBatch                           │
└──────────────────┬──────────────────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────────────────────┐
│ 4. DATABASE (biopotential_batches table)                   │
│    id | recording_id | batch_sequence | sample_rate | ...  │
│    ───┼──────────────┼────────────────┼─────────────┼───── │
│    1  | 123          | 0              | 400.0       | ...  │
│    2  | 123          | 1              | 400.0       | ...  │
│    3  | 123          | 2              | 400.0       | ...  │
└──────────────────┬──────────────────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────────────────────┐
│ 5. WEBAPP (RecordingsController#data)                      │
│    - Query batches by time range                            │
│    - Return data "as-is" (termasuk sampling_rate)          │
└──────────────────┬──────────────────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────────────────────┐
│ 6. CHART.JS (JavaScript)                                    │
│    - Render 4000 points per 10 detik                        │
│    - X-axis: waktu (detik)                                  │
│    - Y-axis: voltase (mV)                                   │
│    - Grid: 25mm/s horizontal, 10mm/mV vertical             │
└─────────────────────────────────────────────────────────────┘
```

---

## ❌ Yang TIDAK Perlu Diubah

### 1. **Database Schema**
✅ Field `sample_rate` di tabel `biopotential_batches` adalah **FLOAT**  
✅ Sudah mendukung any value (100, 200, 400, 500, 1000, dll)  
✅ Tidak perlu migration

### 2. **Model Validations** (`app/models/biopotential_batch.rb`)
✅ Validation: `sample_rate > 0` (fleksibel)  
✅ Tidak hardcode value tertentu

### 3. **JavaScript Chart Logic** (`view_recording.html.erb`)
✅ Chart render based on actual data timestamps  
✅ Tidak asumsi sampling rate tertentu  
✅ Akan otomatis adjust ke 400 Hz jika data adalah 400 Hz

### 4. **Controller Data Endpoint** (`RecordingsController#data`)
✅ Return data "as-is" dari database  
✅ Tidak modify atau resample  
✅ Client (browser) yang handle rendering

---

## 🧪 Testing

### Test 1: Verify Seeds
```bash
rails db:reset
rails db:seed

# Check sampling rate
rails c
> Recording.first.sample_rate
# => 400.0

> Recording.first.biopotential_batches.first.sample_rate
# => 400.0

> Recording.first.biopotential_batches.first.samples.size
# => 4000
```

### Test 2: Mobile API Test
```bash
# Create recording
curl -X POST http://localhost:3000/api/recordings/start \
  -H "Content-Type: application/json" \
  -d '{
    "session_id": "test_session_123",
    "sample_rate": 400
  }'

# Send batch data
curl -X POST http://localhost:3000/api/recordings/data \
  -H "Content-Type: application/json" \
  -d '{
    "recording_id": 1,
    "batch_data": {
      "batch_sequence": 0,
      "sampling_rate": 400,
      "start_timestamp": "2025-11-29T10:00:00.000Z",
      "end_timestamp": "2025-11-29T10:00:10.000Z",
      "samples": [0.1, 0.2, ... 4000 items]
    }
  }'
```

### Test 3: Verify in Browser
1. Open recording: `http://localhost:3000/dashboard/recordings/1`
2. Check "Sample Rate" display → Should show **400 Hz**
3. Open browser console
4. Check API response:
```javascript
// Should see:
{
  type: "raw",
  data: [...],  // 4000 points per 10s
  meta: {
    sample_count: 4000,
    sample_rate: 400
  }
}
```

---

## 🔧 Troubleshooting

### Problem 1: Chart masih tampilkan "500 Hz"

**Cause:** Recording lama masih pakai 500 Hz  
**Fix:**
```bash
rails db:reset
rails db:seed
```

### Problem 2: Mobile app kirim 5000 samples tapi metadata 400 Hz

**Cause:** Mobile belum ubah sample collection  
**Fix:** Update mobile app collection logic:
```dart
// Collect untuk 10 detik @ 400 Hz
const samplingRate = 400;
const durationSeconds = 10;
const expectedSamples = samplingRate * durationSeconds; // 4000

List<double> samples = [];
for (int i = 0; i < expectedSamples; i++) {
  double value = await readADC();
  samples.add(value);
  await Future.delayed(Duration(microseconds: 2500)); // 1/400 Hz = 2500 µs
}
```

### Problem 3: Data count mismatch

**Symptom:** `sample_count` tidak cocok dengan array length  
**Fix:** Pastikan mobile kirim exact 4000 samples:
```dart
assert(samples.length == 4000, 'Expected 4000 samples, got ${samples.length}');
```

---

## 📝 Checklist Migration

Tim Mobile:
- [ ] Ubah `sampling_rate: 500` → `400` di batch metadata
- [ ] Ubah collection loop dari 5000 → 4000 samples per 10 detik
- [ ] Adjust delay: `1/400 Hz = 2.5ms` (2500 microseconds)
- [ ] Test dengan real device
- [ ] Verify batch size di network inspector

Tim Backend:
- [x] Update seeds.rb default ke 400 Hz
- [x] Update API controller fallback ke 400 Hz
- [x] Update view display default ke 400 Hz
- [ ] Test seed data generation
- [ ] Verify API accepts 400 Hz batches

Tim QA:
- [ ] Test recording baru dengan 400 Hz
- [ ] Verify chart renders correctly
- [ ] Check data completeness (4000/batch, bukan 5000)
- [ ] Test backward compatibility (old 500 Hz recordings)

---

## 🎓 FAQ

**Q: Apakah recording lama (500 Hz) akan error?**  
A: ❌ Tidak! System sudah dinamis. Recording lama tetap jalan dengan 500 Hz, recording baru pakai 400 Hz.

**Q: Apakah perlu migration database?**  
A: ❌ Tidak! Field `sample_rate` sudah ada dan flexible.

**Q: Apakah chart akan rusak jika mix 400 Hz dan 500 Hz?**  
A: ❌ Tidak! Chart render by timestamp, bukan by sample count.

**Q: Apa keuntungan 400 Hz vs 500 Hz?**  
A:
- ✅ Storage: 20% lebih kecil (4000 vs 5000 per 10s)
- ✅ Network: 20% lebih sedikit data transfer
- ✅ Processing: 20% lebih cepat
- ✅ Masih cukup untuk EKG diagnosis (standard 250-500 Hz)

**Q: Apakah 400 Hz cukup untuk EKG?**  
A: ✅ Ya! Medical standard:
- Minimum: **250 Hz** (diagnostic EKG)
- Standard: **500 Hz** (hospital-grade)
- High-end: **1000 Hz** (research-grade)
- **400 Hz** adalah sweet spot antara quality dan efficiency

**Q: Kalau mau ganti ke sampling rate lain (misalnya 250 Hz)?**  
A: Ubah semua angka `400` di guide ini ke `250`, dan:
- 10 detik @ 250 Hz = **2500 samples**
- Delay: `1/250 = 4ms`

---

## 📚 References

- **Medical Standard:** AHA/ACC Guidelines for ECG sampling rate (≥250 Hz)
- **Nyquist Theorem:** Sample at ≥2× highest frequency (EKG max ~150 Hz → need ≥300 Hz)
- **Rails API Docs:** See `app/controllers/api/recordings_controller.rb`
- **Mobile Integration:** See `FOR_MOBILE_TEAM_URGENT.md`

---

**Last Updated:** November 29, 2025  
**Author:** Backend Team  
**Version:** 1.0 (400 Hz migration guide)
