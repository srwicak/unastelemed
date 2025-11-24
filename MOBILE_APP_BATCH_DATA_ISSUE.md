# 🔴 CRITICAL: Mobile App Batch Data Issue

## Problem Description

The mobile app is currently **NOT sending batch data** to the server during recording sessions. This causes:

- ❌ `total_samples` remains `NULL` in the database
- ❌ `biopotential_batches` table has no data
- ❌ Doctors cannot view EKG waveforms
- ❌ Only recording metadata is saved (start time, end time, duration)

## Current Mobile App Behavior (WRONG)

```
1. POST /api/recordings/start  ✅ Working
   └─ Response: recording_id, session_id

2. [Recording in progress]     ❌ NO DATA SENT TO SERVER
   └─ Mobile app collects 26,578 samples
   └─ Mobile app does NOT call /api/recordings/data

3. POST /api/recordings/stop   ✅ Working
   └─ Request: only sends summary (duration, total_batches, total_samples)
   └─ Response: recording stopped
```

## Expected Mobile App Behavior (CORRECT)

```
1. POST /api/recordings/start  ✅
   └─ Response: recording_id, session_id

2. [Recording in progress]     ✅ SEND DATA EVERY 10 SECONDS
   ├─ POST /api/recordings/data (batch 0: samples 0-4999)
   ├─ POST /api/recordings/data (batch 1: samples 5000-9999)
   ├─ POST /api/recordings/data (batch 2: samples 10000-14999)
   └─ ... continue every 10 seconds

3. POST /api/recordings/stop   ✅
   └─ Request: just stop signal
   └─ Response: recording stopped with total_samples & total_batches
```

## Solution 1: Fix Mobile App (RECOMMENDED)

### Implementation Steps

1. **Create a batch buffer in mobile app:**

```dart
class BatchBuffer {
  List<double> samples = [];
  DateTime? startTimestamp;
  int batchSequence = 0;
  static const int SAMPLES_PER_BATCH = 5000; // 10 seconds at 500Hz
  
  void addSample(double value) {
    if (samples.isEmpty) {
      startTimestamp = DateTime.now();
    }
    
    samples.add(value);
    
    // Send batch when we reach 5000 samples (10 seconds)
    if (samples.length >= SAMPLES_PER_BATCH) {
      sendBatchToServer();
    }
  }
  
  Future<void> sendBatchToServer() async {
    if (samples.isEmpty) return;
    
    final endTimestamp = DateTime.now();
    
    final response = await http.post(
      Uri.parse('$baseUrl/api/recordings/data'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'recording_id': recordingId,
        'batch_data': {
          'batch_sequence': batchSequence,
          'start_timestamp': startTimestamp!.toIso8601String(),
          'end_timestamp': endTimestamp.toIso8601String(),
          'sample_rate': 500.0,
          'samples': samples,
        }
      }),
    );
    
    if (response.statusCode == 201) {
      print('✅ Batch $batchSequence sent successfully');
      batchSequence++;
      samples.clear();
      startTimestamp = null;
    } else {
      print('❌ Failed to send batch $batchSequence');
      // Implement retry logic here
    }
  }
}
```

2. **Integrate with your recording loop:**

```dart
final batchBuffer = BatchBuffer();

// In your BLE data callback
bleDevice.onDataReceived((double sample) {
  // Add sample to buffer (will auto-send when reaches 5000 samples)
  batchBuffer.addSample(sample);
});

// When stopping recording, send remaining samples
await batchBuffer.sendBatchToServer(); // Send last partial batch
await stopRecording();
```

3. **Add retry logic for failed batches:**

```dart
class BatchBuffer {
  // ... existing code ...
  
  Map<int, Map<String, dynamic>> failedBatches = {};
  
  Future<void> sendBatchToServer() async {
    // ... existing code ...
    
    if (response.statusCode != 201) {
      // Store failed batch for retry
      failedBatches[batchSequence] = {
        'batch_sequence': batchSequence,
        'start_timestamp': startTimestamp!.toIso8601String(),
        'end_timestamp': endTimestamp.toIso8601String(),
        'sample_rate': 500.0,
        'samples': List.from(samples),
      };
      
      // Retry after 2 seconds
      Future.delayed(Duration(seconds: 2), () => retryFailedBatch(batchSequence));
    }
  }
  
  Future<void> retryFailedBatch(int sequence) async {
    if (!failedBatches.containsKey(sequence)) return;
    
    final batchData = failedBatches[sequence]!;
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
    }
  }
  
  Future<void> retryAllFailedBatches() async {
    for (var sequence in failedBatches.keys.toList()) {
      await retryFailedBatch(sequence);
    }
  }
}
```

## Solution 2: Workaround - Send All Batches on Stop (TEMPORARY)

**⚠️ This is a temporary workaround. The proper solution is Solution 1.**

If you cannot implement real-time batch sending immediately, you can send all batches when stopping the recording:

```dart
// Collect all batches during recording
List<Map<String, dynamic>> allBatches = [];
int batchSequence = 0;

// During recording, store batches locally
void onDataReceived(List<double> samples) {
  allBatches.add({
    'batch_sequence': batchSequence++,
    'start_timestamp': startTime.toIso8601String(),
    'end_timestamp': endTime.toIso8601String(),
    'sample_rate': 500.0,
    'samples': samples,
  });
}

// When stopping, send all batches at once
Future<void> stopRecording() async {
  final response = await http.post(
    Uri.parse('$baseUrl/api/recordings/stop'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({
      'recording_id': recordingId,
      'batches': allBatches, // Send all batches here
    }),
  );
  
  if (response.statusCode == 200) {
    print('✅ Recording stopped with ${allBatches.length} batches');
  }
}
```

**Limitations of workaround:**
- ❌ May timeout for long recordings (>5 minutes)
- ❌ Large payload size (several MB)
- ❌ No real-time progress for doctors
- ❌ Risk of data loss if app crashes before stop
- ❌ High memory usage on mobile device

## Testing the Fix

### Test with cURL

```bash
# Start recording
RECORDING_ID=$(curl -X POST http://localhost:3000/api/recordings/start \
  -H "Content-Type: application/json" \
  -d '{"session_id": "test_session_123", "sample_rate": 500.0}' \
  | jq -r '.data.recording_id')

echo "Recording ID: $RECORDING_ID"

# Send batch 0 (first 10 seconds)
curl -X POST http://localhost:3000/api/recordings/data \
  -H "Content-Type: application/json" \
  -d "{
    \"recording_id\": $RECORDING_ID,
    \"batch_data\": {
      \"batch_sequence\": 0,
      \"start_timestamp\": \"2024-01-15T10:30:00.000Z\",
      \"end_timestamp\": \"2024-01-15T10:30:10.000Z\",
      \"sample_rate\": 500.0,
      \"samples\": $(python3 -c 'import json; print(json.dumps([0.5 + i*0.001 for i in range(5000)]))')
    }
  }"

# Send batch 1 (next 10 seconds)
curl -X POST http://localhost:3000/api/recordings/data \
  -H "Content-Type: application/json" \
  -d "{
    \"recording_id\": $RECORDING_ID,
    \"batch_data\": {
      \"batch_sequence\": 1,
      \"start_timestamp\": \"2024-01-15T10:30:10.000Z\",
      \"end_timestamp\": \"2024-01-15T10:30:20.000Z\",
      \"sample_rate\": 500.0,
      \"samples\": $(python3 -c 'import json; print(json.dumps([0.5 + i*0.001 for i in range(5000)]))')
    }
  }"

# Stop recording
curl -X POST http://localhost:3000/api/recordings/stop \
  -H "Content-Type: application/json" \
  -d "{\"recording_id\": $RECORDING_ID}"

# Verify data was saved
echo "Check total samples and batches:"
curl http://localhost:3000/api/recordings/$RECORDING_ID | jq '.data.recording | {total_samples, total_batches}'
```

### Verify in Database

```sql
-- Check recording
SELECT id, status, start_time, end_time, duration_seconds, total_samples 
FROM recordings 
WHERE id = YOUR_RECORDING_ID;

-- Check batches
SELECT id, batch_sequence, sample_count, start_timestamp, end_timestamp
FROM biopotential_batches
WHERE recording_id = YOUR_RECORDING_ID
ORDER BY batch_sequence;

-- Should show:
-- | batch_sequence | sample_count | start_timestamp | end_timestamp |
-- |----------------|--------------|-----------------|---------------|
-- | 0              | 5000         | 10:30:00        | 10:30:10      |
-- | 1              | 5000         | 10:30:10        | 10:30:20      |
-- | ...            | ...          | ...             | ...           |
```

## Summary

| Aspect | Current (BROKEN) | Solution 1 (RECOMMENDED) | Solution 2 (WORKAROUND) |
|--------|------------------|--------------------------|-------------------------|
| Data Sent | ❌ None | ✅ Every 10 seconds | ⚠️ All at stop |
| Database | ❌ Empty | ✅ Populated | ⚠️ Populated |
| Real-time View | ❌ No | ✅ Yes | ❌ No |
| Memory Usage | ⚠️ High | ✅ Low | ❌ Very High |
| Network | ✅ Minimal | ✅ Optimal | ❌ Large burst |
| Reliability | ❌ Low | ✅ High | ⚠️ Medium |
| Max Duration | N/A | ✅ Unlimited | ❌ ~5 minutes |

## Action Items for Mobile Team

1. ✅ **IMMEDIATE:** Implement Solution 1 (real-time batch sending)
2. ⏳ **SHORT-TERM:** Add retry logic for failed batches
3. 📊 **TESTING:** Use the cURL test script to verify
4. 🐛 **DEBUG:** Enable logging to see batch send status
5. 📱 **UI:** Add batch upload progress indicator

## Backend Changes (COMPLETED)

- ✅ `/api/recordings/data` endpoint supports batch format
- ✅ `/api/recordings/stop` endpoint accepts batches array (workaround)
- ✅ Duplicate batch detection (idempotent)
- ✅ Optimized database storage (JSONB)
- ✅ Fast chart data retrieval

## Questions?

Contact backend team or check:
- `MOBILE_APP_API.md` - Full API documentation
- `BATCH_STORAGE_IMPLEMENTATION.md` - Backend implementation details
