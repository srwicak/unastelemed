# 🔄 Panduan Recovery Data EKG yang Tidak Lengkap

## 📋 Ringkasan Masalah

Jika mobile app gagal mengirim semua batch data selama recording (karena koneksi terputus atau error lainnya), grafik EKG tidak akan muncul di web dashboard karena data tidak lengkap.

**Solusi:** Mobile app bisa mengirim ulang data yang tertinggal menggunakan endpoint recovery.

---

## ✅ Solusi 1: Recovery Data Setelah Recording Selesai

### Endpoint: `POST /api/recordings/:id/recover_data`

Gunakan endpoint ini untuk mengirim batch data yang tertinggal SETELAH recording selesai.

### Request Format

```bash
POST /api/recordings/{recording_id}/recover_data
Content-Type: application/json

{
  "batches": [
    {
      "batch_sequence": 0,
      "start_timestamp": "2024-01-15T10:30:00.000Z",
      "end_timestamp": "2024-01-15T10:30:10.000Z",
      "sample_rate": 500.0,
      "samples": [0.523, 0.481, -0.123, 0.445, ...]  // Array of 5000 values
    },
    {
      "batch_sequence": 1,
      "start_timestamp": "2024-01-15T10:30:10.000Z",
      "end_timestamp": "2024-01-15T10:30:20.000Z",
      "sample_rate": 500.0,
      "samples": [0.612, 0.571, -0.089, 0.534, ...]
    }
    // ... more batches
  ]
}
```

### Response Format

```json
{
  "success": true,
  "message": "Data recovery selesai",
  "data": {
    "recording_id": 123,
    "session_id": "abc123",
    "processed_count": 45,
    "duplicate_count": 3,
    "failed_count": 0,
    "total_batches": 48,
    "total_samples": 240000,
    "processed_batches": [
      {
        "batch_sequence": 0,
        "samples_count": 5000
      }
      // ... list of successfully processed batches
    ],
    "duplicate_batches": [
      {
        "batch_sequence": 1,
        "message": "Batch sudah ada"
      }
      // ... list of batches that were already uploaded
    ],
    "failed_batches": []  // Empty if all succeeded
  }
}
```

---

## 🔧 Implementasi di Flutter/Dart

### 1. Buffer Data Lokal Selama Recording

```dart
class EKGRecordingService {
  List<BatchData> _pendingBatches = [];
  bool _isRecording = false;
  int _recordingId;
  
  // Buffer untuk menyimpan batch yang gagal dikirim
  Future<void> saveBatchLocally(BatchData batch) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'pending_batch_${_recordingId}_${batch.batchSequence}';
    final json = jsonEncode(batch.toJson());
    await prefs.setString(key, json);
  }
  
  // Kirim batch dengan retry logic
  Future<bool> sendBatchWithRetry(BatchData batch, {int maxRetries = 3}) async {
    for (int attempt = 0; attempt < maxRetries; attempt++) {
      try {
        final response = await http.post(
          Uri.parse('$baseUrl/api/recordings/data'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'recording_id': _recordingId,
            'batch_data': batch.toJson(),
          }),
        );
        
        if (response.statusCode == 200 || response.statusCode == 201) {
          print('✅ Batch ${batch.batchSequence} sent successfully');
          return true;
        }
      } catch (e) {
        print('⚠️ Attempt ${attempt + 1} failed: $e');
        if (attempt < maxRetries - 1) {
          await Future.delayed(Duration(seconds: 2 * (attempt + 1)));
        }
      }
    }
    
    // Jika gagal semua retry, simpan lokal
    print('❌ Failed to send batch ${batch.batchSequence}, saving locally');
    await saveBatchLocally(batch);
    return false;
  }
}
```

### 2. Recovery Data Setelah Recording Selesai

```dart
class DataRecoveryService {
  final String baseUrl;
  
  DataRecoveryService(this.baseUrl);
  
  // Ambil semua batch yang gagal dikirim dari local storage
  Future<List<BatchData>> getPendingBatches(int recordingId) async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys()
        .where((key) => key.startsWith('pending_batch_$recordingId'))
        .toList();
    
    List<BatchData> batches = [];
    for (String key in keys) {
      final jsonStr = prefs.getString(key);
      if (jsonStr != null) {
        batches.add(BatchData.fromJson(jsonDecode(jsonStr)));
      }
    }
    
    // Sort by batch_sequence
    batches.sort((a, b) => a.batchSequence.compareTo(b.batchSequence));
    return batches;
  }
  
  // Kirim semua batch yang tertinggal ke server
  Future<RecoveryResult> recoverData(int recordingId) async {
    final pendingBatches = await getPendingBatches(recordingId);
    
    if (pendingBatches.isEmpty) {
      print('✅ No pending batches for recovery');
      return RecoveryResult(success: true, message: 'No data to recover');
    }
    
    print('🔄 Recovering ${pendingBatches.length} batches...');
    
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/recordings/$recordingId/recover_data'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'batches': pendingBatches.map((b) => b.toJson()).toList(),
        }),
      );
      
      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        print('✅ Recovery successful:');
        print('  - Processed: ${result['data']['processed_count']}');
        print('  - Duplicates: ${result['data']['duplicate_count']}');
        print('  - Failed: ${result['data']['failed_count']}');
        
        // Hapus batch yang berhasil dikirim dari local storage
        if (result['data']['failed_count'] == 0) {
          await clearPendingBatches(recordingId);
        } else {
          // Hapus hanya yang berhasil
          await clearSuccessfulBatches(
            recordingId,
            result['data']['processed_batches'],
            result['data']['duplicate_batches']
          );
        }
        
        return RecoveryResult.fromJson(result);
      } else {
        print('❌ Recovery failed: ${response.statusCode}');
        return RecoveryResult(
          success: false,
          message: 'Server returned ${response.statusCode}'
        );
      }
    } catch (e) {
      print('❌ Recovery error: $e');
      return RecoveryResult(success: false, message: e.toString());
    }
  }
  
  // Hapus semua pending batches untuk recording tertentu
  Future<void> clearPendingBatches(int recordingId) async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys()
        .where((key) => key.startsWith('pending_batch_$recordingId'))
        .toList();
    
    for (String key in keys) {
      await prefs.remove(key);
    }
    print('✅ Cleared ${keys.length} pending batches from local storage');
  }
  
  Future<void> clearSuccessfulBatches(
    int recordingId,
    List processedBatches,
    List duplicateBatches
  ) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Hapus processed batches
    for (var batch in processedBatches) {
      final key = 'pending_batch_${recordingId}_${batch['batch_sequence']}';
      await prefs.remove(key);
    }
    
    // Hapus duplicate batches (sudah ada di server)
    for (var batch in duplicateBatches) {
      final key = 'pending_batch_${recordingId}_${batch['batch_sequence']}';
      await prefs.remove(key);
    }
  }
}

// Model classes
class BatchData {
  final int batchSequence;
  final String startTimestamp;
  final String endTimestamp;
  final double sampleRate;
  final List<double> samples;
  
  BatchData({
    required this.batchSequence,
    required this.startTimestamp,
    required this.endTimestamp,
    required this.sampleRate,
    required this.samples,
  });
  
  Map<String, dynamic> toJson() => {
    'batch_sequence': batchSequence,
    'start_timestamp': startTimestamp,
    'end_timestamp': endTimestamp,
    'sample_rate': sampleRate,
    'samples': samples,
  };
  
  factory BatchData.fromJson(Map<String, dynamic> json) => BatchData(
    batchSequence: json['batch_sequence'],
    startTimestamp: json['start_timestamp'],
    endTimestamp: json['end_timestamp'],
    sampleRate: json['sample_rate'],
    samples: List<double>.from(json['samples']),
  );
}

class RecoveryResult {
  final bool success;
  final String message;
  final int? processedCount;
  final int? duplicateCount;
  final int? failedCount;
  final int? totalBatches;
  final int? totalSamples;
  
  RecoveryResult({
    required this.success,
    required this.message,
    this.processedCount,
    this.duplicateCount,
    this.failedCount,
    this.totalBatches,
    this.totalSamples,
  });
  
  factory RecoveryResult.fromJson(Map<String, dynamic> json) => RecoveryResult(
    success: json['success'],
    message: json['message'],
    processedCount: json['data']?['processed_count'],
    duplicateCount: json['data']?['duplicate_count'],
    failedCount: json['data']?['failed_count'],
    totalBatches: json['data']?['total_batches'],
    totalSamples: json['data']?['total_samples'],
  );
}
```

### 3. Integrasi di Flow Recording

```dart
class RecordingScreen extends StatefulWidget {
  @override
  _RecordingScreenState createState() => _RecordingScreenState();
}

class _RecordingScreenState extends State<RecordingScreen> {
  final EKGRecordingService _recordingService = EKGRecordingService();
  final DataRecoveryService _recoveryService = DataRecoveryService('http://your-server.com');
  
  Future<void> stopRecording() async {
    // 1. Stop recording di server
    await _recordingService.stopRecording();
    
    // 2. Cek apakah ada batch yang gagal dikirim
    final pendingBatches = await _recoveryService.getPendingBatches(_recordingService.recordingId);
    
    if (pendingBatches.isNotEmpty) {
      // 3. Tampilkan dialog ke user
      final shouldRecover = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('⚠️ Data Tidak Lengkap'),
          content: Text(
            'Ada ${pendingBatches.length} batch data yang gagal dikirim.\n\n'
            'Apakah Anda ingin mengirim ulang data tersebut sekarang?'
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Nanti Saja'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('Kirim Sekarang'),
            ),
          ],
        ),
      );
      
      if (shouldRecover == true) {
        // 4. Recover data
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Mengirim ulang data...'),
              ],
            ),
          ),
        );
        
        final result = await _recoveryService.recoverData(_recordingService.recordingId);
        Navigator.pop(context); // Close loading dialog
        
        // 5. Show result
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(result.success ? '✅ Berhasil' : '❌ Gagal'),
            content: Text(
              result.success
                ? 'Data berhasil dikirim!\n\n'
                  'Processed: ${result.processedCount}\n'
                  'Total Samples: ${result.totalSamples}'
                : 'Gagal mengirim data: ${result.message}'
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('OK'),
              ),
            ],
          ),
        );
      }
    }
    
    // Navigate back
    Navigator.pop(context);
  }
}
```

---

## 📝 Catatan Penting

### ✅ Best Practices

1. **Kirim data real-time selama recording** - Ini tetap prioritas utama
2. **Buffer data lokal** - Simpan batch yang gagal dikirim di local storage
3. **Retry dengan exponential backoff** - Coba kirim ulang beberapa kali sebelum simpan lokal
4. **Recovery setelah recording** - Tawarkan user untuk kirim ulang data setelah recording selesai
5. **Hapus data lokal setelah berhasil** - Jangan biarkan data menumpuk

### ⚠️ Limitasi

- Endpoint recovery hanya bisa digunakan untuk recording yang sudah selesai (`status: 'completed'`)
- Batch dengan `batch_sequence` yang sama akan di-skip (idempotent)
- Maximum batch size: 10,000 samples per batch
- Tidak ada limit jumlah batch yang bisa dikirim dalam satu request recovery

### 🔍 Debugging

Jika recovery gagal, periksa:
1. Recording ID valid dan recording sudah selesai
2. Format batch data sesuai dengan yang diharapkan
3. Timestamp dalam format ISO 8601 UTC
4. Sample rate adalah 500.0 (float)
5. Samples adalah array of numbers

---

## 📊 Status Data di Web Dashboard

Setelah implementasi ini, web dashboard akan menampilkan status data:

- ✅ **Data EKG lengkap** - Semua batch tersimpan dengan baik
- ⏳ **Recording sedang berlangsung** - Menunggu data dari mobile app
- ⚠️ **Data EKG tidak tersimpan** - Mobile app tidak mengirim batch data
- ⚠️ **Data EKG tidak lengkap** - Beberapa batch hilang

Dashboard akan memberikan informasi detail tentang:
- Kemungkinan penyebab masalah
- Saran untuk perbaikan
- Langkah-langkah untuk recording ulang

---

## 🧪 Testing

### Test dengan cURL

```bash
# 1. Start recording
RECORDING_ID=$(curl -X POST http://localhost:3000/api/recordings/start \
  -H "Content-Type: application/json" \
  -d '{"session_id": "test123", "sample_rate": 500.0}' | jq -r '.data.recording_id')

echo "Recording ID: $RECORDING_ID"

# 2. Stop recording tanpa mengirim data
curl -X POST http://localhost:3000/api/recordings/stop \
  -H "Content-Type: application/json" \
  -d "{\"recording_id\": $RECORDING_ID}"

# 3. Kirim data yang "tertinggal" via recovery endpoint
curl -X POST "http://localhost:3000/api/recordings/$RECORDING_ID/recover_data" \
  -H "Content-Type: application/json" \
  -d "{
    \"batches\": [
      {
        \"batch_sequence\": 0,
        \"start_timestamp\": \"2024-01-15T10:30:00.000Z\",
        \"end_timestamp\": \"2024-01-15T10:30:10.000Z\",
        \"sample_rate\": 500.0,
        \"samples\": $(python3 -c 'import json; print(json.dumps([0.5 + i*0.001 for i in range(5000)]))')
      },
      {
        \"batch_sequence\": 1,
        \"start_timestamp\": \"2024-01-15T10:30:10.000Z\",
        \"end_timestamp\": \"2024-01-15T10:30:20.000Z\",
        \"sample_rate\": 500.0,
        \"samples\": $(python3 -c 'import json; print(json.dumps([0.5 + i*0.001 for i in range(5000)]))')
      }
    ]
  }" | jq

# 4. Verify data
curl "http://localhost:3000/api/recordings/$RECORDING_ID" | jq '.data | {total_samples, total_batches, status}'
```

---

## 📞 Support

Jika ada masalah, hubungi tim backend atau buat issue di repository.
