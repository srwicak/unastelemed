# 🔴 CRITICAL BUG: Data Tidak Tersimpan di Server

## Masalah

Mobile app saat ini **TIDAK mengirim data EKG ke server**. Hanya metadata (start/stop) yang terkirim.

**Bukti:**
```sql
-- Recordings yang dibuat dari mobile app:
SELECT id, total_samples FROM recordings WHERE id IN (4,5,6,7,8,9,10,11,12,13,14,16);
-- Result: total_samples = NULL ❌

-- Tidak ada data di biopotential_batches:
SELECT COUNT(*) FROM biopotential_batches WHERE recording_id = 16;
-- Result: 0 ❌
```

Padahal mobile app mengatakan ada **26,578 samples** yang direcord.

---

## Solusi Cepat

Mobile app HARUS memanggil endpoint ini **setiap 10 detik** selama recording:

```dart
POST /api/recordings/data

Body:
{
  "recording_id": 16,
  "batch_data": {
    "batch_sequence": 0,  // Increment: 0, 1, 2, ...
    "start_timestamp": "2024-01-15T10:30:00.000Z",
    "end_timestamp": "2024-01-15T10:30:10.000Z",
    "sample_rate": 500.0,
    "samples": [0.523, 0.481, -0.123, ...]  // 5000 values
  }
}
```

---

## Code Flutter

```dart
class EKGBatchBuffer {
  List<double> samples = [];
  int batchSequence = 0;
  final int recordingId;
  
  EKGBatchBuffer(this.recordingId);
  
  void addSample(double sample) {
    samples.add(sample);
    
    // Send batch setiap 5000 samples (10 detik di 500Hz)
    if (samples.length >= 5000) {
      _sendBatch();
    }
  }
  
  Future<void> _sendBatch() async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/recordings/data'),
      body: jsonEncode({
        'recording_id': recordingId,
        'batch_data': {
          'batch_sequence': batchSequence++,
          'start_timestamp': DateTime.now().toUtc().toIso8601String(),
          'end_timestamp': DateTime.now().add(Duration(seconds: 10)).toUtc().toIso8601String(),
          'sample_rate': 500.0,
          'samples': samples,
        }
      }),
    );
    
    if (response.statusCode == 201) {
      print('✅ Batch $batchSequence terkirim');
      samples.clear();
    }
  }
}

// Gunakan di recording service:
final buffer = EKGBatchBuffer(recordingId);

// Setiap dapat data dari BLE:
bleDevice.onDataReceived((sample) {
  buffer.addSample(sample);  // Otomatis kirim setiap 5000 samples
});

// Sebelum stop:
buffer._sendBatch();  // Kirim sisa data
stopRecording();
```

---

## Testing

Backend sudah 100% siap dan teruji:

```bash
✅ Tested: Recording ID 18
✅ Batch 0: 5000 samples tersimpan
✅ Batch 1: 5000 samples tersimpan
✅ Total: 10,000 samples di database
```

Test sendiri dengan cURL:
```bash
# Lihat file FOR_MOBILE_TEAM_URGENT.md untuk test script lengkap
```

---

## Dokumentasi Lengkap

1. **FOR_MOBILE_TEAM_URGENT.md** ← Baca ini untuk detail lengkap
2. **MOBILE_APP_API.md** ← API documentation
3. **MOBILE_APP_BATCH_DATA_ISSUE.md** ← Analisa masalah detail

---

## Action Required

1. ✅ Implement `EKGBatchBuffer` class
2. ✅ Panggil `buffer.addSample()` setiap dapat data BLE
3. ✅ Test dengan recording 1 menit
4. ✅ Verify di dashboard web ada grafik EKG

**Estimasi:** 2-4 jam

**Priority:** 🔴 CRITICAL - Fitur utama app tidak jalan!
