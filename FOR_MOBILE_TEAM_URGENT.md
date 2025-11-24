# 🚨 URGENT: Mobile App MUST Send Batch Data

## Executive Summary

**Problem:** Mobile app tidak mengirim sample data ke server selama recording. Hanya mengirim metadata (start/stop).

**Impact:** 
- ❌ Database `total_samples` = NULL
- ❌ Table `biopotential_batches` kosong
- ❌ Dokter tidak bisa lihat grafik EKG
- ❌ Fitur utama aplikasi tidak berfungsi

**Solution:** Mobile app harus memanggil endpoint `/api/recordings/data` setiap 10 detik selama recording.

---

## ✅ Backend Status: READY

Backend sudah 100% siap dan teruji untuk menerima batch data:

```bash
✅ POST /api/recordings/start   - Working
✅ POST /api/recordings/data    - Working (TESTED!)
✅ POST /api/recordings/stop    - Working
✅ Database storage             - Working
✅ Batch deduplication          - Working (idempotent)
```

**Test Results:**
```
Recording ID: 18
├─ Batch 0: 5000 samples ✅
├─ Batch 1: 5000 samples ✅
└─ Total: 10,000 samples in database ✅
```

---

## 🔧 What Mobile App Must Do

### Current Flow (WRONG ❌)
```
Start Recording → [Collect Data Locally] → Stop Recording
                   ↑ NO DATA SENT TO SERVER ❌
```

### Correct Flow (REQUIRED ✅)
```
Start Recording → [Collect Data]
                      ↓ Every 10 seconds
                  Send Batch to Server
                      ↓
                  [Continue Recording]
                      ↓ Every 10 seconds
                  Send Next Batch
                      ↓
                  Stop Recording
```

---

## 📋 Implementation Checklist for Mobile Team

### Step 1: Create Batch Buffer (REQUIRED)

```dart
class EKGBatchBuffer {
  List<double> samples = [];
  DateTime? batchStartTime;
  int batchSequence = 0;
  int recordingId;
  
  static const int SAMPLES_PER_BATCH = 5000; // 10 seconds at 500Hz
  static const double SAMPLE_RATE = 500.0;
  
  EKGBatchBuffer(this.recordingId);
  
  /// Add a sample to the buffer
  void addSample(double sample) {
    if (samples.isEmpty) {
      batchStartTime = DateTime.now();
    }
    
    samples.add(sample);
    
    // Auto-send when buffer is full
    if (samples.length >= SAMPLES_PER_BATCH) {
      sendBatch();
    }
  }
  
  /// Send batch to server
  Future<bool> sendBatch() async {
    if (samples.isEmpty) return true;
    
    final endTime = DateTime.now();
    
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/recordings/data'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'recording_id': recordingId,
          'batch_data': {
            'batch_sequence': batchSequence,
            'start_timestamp': batchStartTime!.toUtc().toIso8601String(),
            'end_timestamp': endTime.toUtc().toIso8601String(),
            'sample_rate': SAMPLE_RATE,
            'samples': samples,
          }
        }),
      );
      
      if (response.statusCode == 201 || response.statusCode == 200) {
        print('✅ Batch $batchSequence sent (${samples.length} samples)');
        batchSequence++;
        samples.clear();
        batchStartTime = null;
        return true;
      } else {
        print('❌ Failed to send batch $batchSequence: ${response.body}');
        return false;
      }
    } catch (e) {
      print('❌ Error sending batch $batchSequence: $e');
      return false;
    }
  }
  
  /// Send remaining samples (call before stopping recording)
  Future<bool> flush() async {
    if (samples.isEmpty) return true;
    return await sendBatch();
  }
}
```

### Step 2: Integrate with BLE Data Stream

```dart
class RecordingService {
  EKGBatchBuffer? _batchBuffer;
  
  Future<void> startRecording() async {
    // 1. Call /api/recordings/start
    final response = await http.post(
      Uri.parse('$baseUrl/api/recordings/start'),
      body: jsonEncode({
        'session_id': sessionId,
        'sample_rate': 500.0,
      }),
    );
    
    final recordingId = jsonDecode(response.body)['data']['recording_id'];
    
    // 2. Initialize batch buffer
    _batchBuffer = EKGBatchBuffer(recordingId);
    
    // 3. Start BLE data stream
    startBLEDataStream();
  }
  
  void onBLEDataReceived(double sample) {
    // Add sample to buffer (will auto-send every 5000 samples)
    _batchBuffer?.addSample(sample);
  }
  
  Future<void> stopRecording() async {
    // 1. Flush remaining samples
    await _batchBuffer?.flush();
    
    // 2. Call /api/recordings/stop
    await http.post(
      Uri.parse('$baseUrl/api/recordings/stop'),
      body: jsonEncode({
        'recording_id': _batchBuffer!.recordingId,
      }),
    );
    
    // 3. Cleanup
    _batchBuffer = null;
  }
}
```

### Step 3: Add Retry Logic (RECOMMENDED)

```dart
class EKGBatchBuffer {
  // ... previous code ...
  
  Map<int, Map<String, dynamic>> failedBatches = {};
  
  Future<bool> sendBatch() async {
    // ... previous sending code ...
    
    if (response.statusCode != 201 && response.statusCode != 200) {
      // Store failed batch
      failedBatches[batchSequence] = {
        'batch_sequence': batchSequence,
        'start_timestamp': batchStartTime!.toUtc().toIso8601String(),
        'end_timestamp': endTime.toUtc().toIso8601String(),
        'sample_rate': SAMPLE_RATE,
        'samples': List.from(samples), // Make a copy
      };
      
      // Retry after 2 seconds
      Future.delayed(Duration(seconds: 2), () => retryBatch(batchSequence));
      
      // Clear buffer to continue with next batch
      batchSequence++;
      samples.clear();
      batchStartTime = null;
      
      return false;
    }
    
    // Success case remains the same...
  }
  
  Future<void> retryBatch(int sequence) async {
    if (!failedBatches.containsKey(sequence)) return;
    
    final batchData = failedBatches[sequence]!;
    
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/recordings/data'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'recording_id': recordingId,
          'batch_data': batchData,
        }),
      );
      
      if (response.statusCode == 201 || response.statusCode == 200) {
        print('✅ Retry successful for batch $sequence');
        failedBatches.remove(sequence);
      } else {
        print('⚠️ Retry failed for batch $sequence, will try again later');
        // Retry again after 5 seconds
        Future.delayed(Duration(seconds: 5), () => retryBatch(sequence));
      }
    } catch (e) {
      print('❌ Retry error for batch $sequence: $e');
      // Retry again after 5 seconds
      Future.delayed(Duration(seconds: 5), () => retryBatch(sequence));
    }
  }
  
  Future<void> retryAllFailedBatches() async {
    print('Retrying ${failedBatches.length} failed batches...');
    for (var sequence in failedBatches.keys.toList()) {
      await retryBatch(sequence);
      await Future.delayed(Duration(milliseconds: 100)); // Small delay between retries
    }
  }
}
```

---

## 🧪 Testing Instructions

### Test 1: Manual cURL Test

```bash
# 1. Get a valid session_id from QR code scan
SESSION_ID="your_session_id_here"

# 2. Start recording
RESPONSE=$(curl -X POST http://localhost:3000/api/recordings/start \
  -H "Content-Type: application/json" \
  -d "{\"session_id\": \"$SESSION_ID\", \"sample_rate\": 500.0}")

echo "$RESPONSE"
RECORDING_ID=$(echo "$RESPONSE" | jq -r '.data.recording_id')

# 3. Send test batch
curl -X POST http://localhost:3000/api/recordings/data \
  -H "Content-Type: application/json" \
  -d "{
    \"recording_id\": $RECORDING_ID,
    \"batch_data\": {
      \"batch_sequence\": 0,
      \"start_timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%S.000Z)\",
      \"end_timestamp\": \"$(date -u -d '+10 seconds' +%Y-%m-%dT%H:%M:%S.000Z)\",
      \"sample_rate\": 500.0,
      \"samples\": [0.5, 0.51, 0.52, 0.53, 0.54]
    }
  }"

# 4. Stop recording
curl -X POST http://localhost:3000/api/recordings/stop \
  -H "Content-Type: application/json" \
  -d "{\"recording_id\": $RECORDING_ID}"
```

**Expected Result:**
```json
{
  "success": true,
  "message": "Batch data berhasil disimpan",
  "data": {
    "batch_sequence": 0,
    "samples_received": 5,
    "total_samples": 5,
    "total_batches": 1
  }
}
```

### Test 2: Verify in Flutter

Add debug logging:

```dart
class EKGBatchBuffer {
  Future<bool> sendBatch() async {
    print('📤 Sending batch $batchSequence with ${samples.length} samples');
    
    // ... send code ...
    
    if (success) {
      print('✅ Batch $batchSequence sent successfully');
      print('   Server total_samples: ${responseData['total_samples']}');
      print('   Server total_batches: ${responseData['total_batches']}');
    }
  }
}
```

Watch logs during recording:
```
📤 Sending batch 0 with 5000 samples
✅ Batch 0 sent successfully
   Server total_samples: 5000
   Server total_batches: 1
📤 Sending batch 1 with 5000 samples
✅ Batch 1 sent successfully
   Server total_samples: 10000
   Server total_batches: 2
```

---

## ⚠️ Common Mistakes to Avoid

1. **❌ Sending empty samples array**
   ```dart
   // WRONG
   'samples': []  // Backend will reject this
   
   // CORRECT
   'samples': [0.5, 0.51, 0.52, ...]  // At least 1 sample
   ```

2. **❌ Not sending data at all (current issue)**
   ```dart
   // WRONG
   startRecording();
   // ... collect data locally only ...
   stopRecording();
   
   // CORRECT
   startRecording();
   while (recording) {
     collectSample();
     if (buffer.isFull()) {
       buffer.sendBatch();  // Send to server!
     }
   }
   stopRecording();
   ```

3. **❌ Wrong timestamp format**
   ```dart
   // WRONG
   'start_timestamp': '2024-01-15 10:30:00'
   
   // CORRECT
   'start_timestamp': '2024-01-15T10:30:00.000Z'  // ISO 8601 with Z
   ```

4. **❌ Sending summary only in stop request**
   ```dart
   // WRONG (current behavior)
   stopRecording(summary: {'total_samples': 26578})  // Data not saved!
   
   // CORRECT
   sendBatch();  // Send actual samples during recording
   stopRecording();  // Just stop, no summary needed
   ```

---

## 📊 Performance Metrics

### Expected Behavior

For a 1-minute recording at 500Hz:
```
Duration:        60 seconds
Sample Rate:     500 Hz
Total Samples:   30,000
Batches:         6 (5000 samples each)
Network Calls:   6 POST requests to /api/recordings/data
Payload Size:    ~20 KB per batch
Total Data:      ~120 KB
```

### Database After Recording

```sql
-- Recording should have:
recordings.total_samples = 30000  ✅ (not NULL!)
recordings.status = 'completed'

-- Batches table should have:
biopotential_batches.count = 6  ✅ (not 0!)
Each batch: 5000 samples
```

---

## 🆘 Support & Contact

If you encounter issues:

1. **Check Rails logs:**
   ```bash
   tail -f log/development.log
   ```

2. **Verify API endpoint is working:**
   ```bash
   curl http://localhost:3000/api/recordings/data -X POST \
     -H "Content-Type: application/json" \
     -d '{"recording_id": 1, "batch_data": {"batch_sequence": 0, ...}}'
   ```

3. **Check mobile app logs:**
   - Are batches being created?
   - Are HTTP requests being sent?
   - What are the response codes?

4. **Contact backend team:**
   - Provide recording_id
   - Provide mobile app logs
   - Provide network request/response dumps

---

## 📚 Additional Documentation

- `MOBILE_APP_API.md` - Complete API documentation
- `MOBILE_APP_BATCH_DATA_ISSUE.md` - Detailed problem analysis
- `BATCH_STORAGE_IMPLEMENTATION.md` - Backend implementation details

---

## ✅ Definition of Done

Mobile app implementation is complete when:

- [x] Mobile app sends batch data every 10 seconds during recording
- [x] Database `recordings.total_samples` is not NULL
- [x] Database `biopotential_batches` has records
- [x] Doctors can view EKG waveforms on web dashboard
- [x] Retry logic handles network failures
- [x] Debug logging shows batch upload progress

---

**DEADLINE:** ASAP - This is blocking the core functionality of the app!

**Priority:** 🔴 CRITICAL - Highest priority

**Estimated Effort:** 2-4 hours for experienced Flutter developer
