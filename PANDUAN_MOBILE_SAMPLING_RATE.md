# 📱 Panduan Mobile App: Mengirim Data EKG dengan Sampling Rate yang Benar

## 🚨 **URGENT: Fix Data Corruption Issue**

**Problem yang terlihat:**
- Sample Rate berantakan: 22.4-395.9 Hz (seharusnya ~400 Hz)
- Chart patah-patah/tidak smooth
- Data reject karena Hz terlalu rendah

**Root Cause:**
- Timestamp calculation salah (milliseconds vs seconds)
- Duration calculation error
- Sample rate calculation error

---

## ✅ **Solusi: Code yang Benar**

### **1. Collect Batch dengan Timing Akurat**

```dart
// SETUP: Define constants
const int TARGET_SAMPLING_RATE = 400; // Hz
const int BATCH_DURATION_SECONDS = 10; // detik per batch
const int TARGET_SAMPLES_PER_BATCH = TARGET_SAMPLING_RATE * BATCH_DURATION_SECONDS; // 4000

// START: Catat waktu mulai
DateTime batchStart = DateTime.now();
List<double> samples = [];

// COLLECT: Ambil samples sampai target tercapai
while (samples.length < TARGET_SAMPLES_PER_BATCH) {
  double value = await readADCValue(); // Baca dari sensor
  samples.add(value);
  
  // Delay untuk maintain ~400 Hz
  // 1/400 Hz = 2.5 milliseconds per sample
  await Future.delayed(Duration(microseconds: 2500));
}

// END: Catat waktu selesai
DateTime batchEnd = DateTime.now();

// CALCULATE: Duration dalam SECONDS (PENTING!)
double durationSeconds = batchEnd.difference(batchStart).inMilliseconds / 1000.0;
//                                                                        ^^^^^^^^
//                                        HARUS DIBAGI 1000 untuk convert ke seconds!

// CALCULATE: Actual sampling rate
double actualSamplingRate = samples.length / durationSeconds;

// LOG: Debug info
print('✅ Batch collected:');
print('   Samples: ${samples.length}');
print('   Duration: ${durationSeconds.toStringAsFixed(3)}s');
print('   Sampling Rate: ${actualSamplingRate.toStringAsFixed(1)} Hz');
```

---

### **2. Validasi Sebelum Kirim**

```dart
// VALIDATE: Pastikan Hz masuk akal (200-600 Hz)
if (actualSamplingRate < 200 || actualSamplingRate > 600) {
  print('❌ ERROR: Sampling rate out of range!');
  print('   Got: ${actualSamplingRate} Hz');
  print('   Expected: 200-600 Hz');
  print('   Duration: ${durationSeconds}s');
  print('   Samples: ${samples.length}');
  print('   ⚠️  BATCH TIDAK DIKIRIM - Ada masalah timing!');
  
  // JANGAN KIRIM batch ini, ada error!
  return null;
}

// VALIDATE: Warning jika terlalu jauh dari target
if (actualSamplingRate < 320 || actualSamplingRate > 480) {
  print('⚠️  WARNING: Sampling rate deviation');
  print('   Got: ${actualSamplingRate} Hz');
  print('   Expected: ~400 Hz (±20%)');
  print('   Batch akan dikirim tapi ada warning');
}
```

---

### **3. Format Data untuk Server**

```dart
// PREPARE: Batch data
final Map<String, dynamic> batchData = {
  'batch_sequence': batchSequence,
  'sampling_rate': actualSamplingRate.roundToDouble(), // ← ACTUAL Hz (bisa 398, 401, 405)
  'sample_count': samples.length,                       // ← Harus match array length
  'start_timestamp': batchStart.toIso8601String(),     // ← ISO format: "2025-11-29T10:00:00.000Z"
  'end_timestamp': batchEnd.toIso8601String(),         // ← ISO format: "2025-11-29T10:00:10.000Z"
  'samples': samples,                                   // ← Array of double values
};

// LOG: Verify format
print('📤 Sending batch data:');
print('   batch_sequence: ${batchData['batch_sequence']}');
print('   sampling_rate: ${batchData['sampling_rate']} Hz');
print('   sample_count: ${batchData['sample_count']}');
print('   start_timestamp: ${batchData['start_timestamp']}');
print('   end_timestamp: ${batchData['end_timestamp']}');
print('   samples length: ${(batchData['samples'] as List).length}');

return batchData;
```

---

## ❌ **KESALAHAN UMUM & FIX**

### **Error 1: Duration dalam Milliseconds (bukan Seconds)**

**❌ SALAH:**
```dart
double duration = batchEnd.difference(batchStart).inMilliseconds;
double hz = samples.length / duration; 
// Hasil: 4000 / 10000 = 0.4 Hz (SALAH TOTAL!)
```

**✅ BENAR:**
```dart
double duration = batchEnd.difference(batchStart).inMilliseconds / 1000.0;
double hz = samples.length / duration;
// Hasil: 4000 / 10.0 = 400 Hz (BENAR!)
```

---

### **Error 2: Timestamp Format Salah**

**❌ SALAH:**
```dart
'start_timestamp': batchStart.millisecondsSinceEpoch, // Integer: 1732874400000
'end_timestamp': batchEnd.millisecondsSinceEpoch,     // Integer: 1732874410000
```

**✅ BENAR:**
```dart
'start_timestamp': batchStart.toIso8601String(), // String: "2025-11-29T10:00:00.000Z"
'end_timestamp': batchEnd.toIso8601String(),     // String: "2025-11-29T10:00:10.000Z"
```

---

### **Error 3: Sample Count Mismatch**

**❌ SALAH:**
```dart
'sample_count': 4000,           // Hardcoded
'samples': samples,             // Array length = 3985 (tidak match!)
```

**✅ BENAR:**
```dart
'sample_count': samples.length, // Dynamic: 3985
'samples': samples,             // Array length = 3985 (MATCH!)
```

---

### **Error 4: Sampling Rate Hardcoded**

**❌ SALAH:**
```dart
'sampling_rate': 400, // Selalu 400, padahal actual bisa 398 atau 405
```

**✅ BENAR:**
```dart
double actualHz = samples.length / durationSeconds;
'sampling_rate': actualHz.roundToDouble(), // Actual: 398, 401, 405, dll
```

---

## 🧪 **Testing & Debugging**

### **Test 1: Log Setiap Batch**

```dart
void logBatchInfo(Map<String, dynamic> batchData) {
  print('═══════════════════════════════════════');
  print('📊 BATCH INFO');
  print('═══════════════════════════════════════');
  print('Sequence: ${batchData['batch_sequence']}');
  print('Sampling Rate: ${batchData['sampling_rate']} Hz');
  print('Sample Count: ${batchData['sample_count']}');
  print('Start Time: ${batchData['start_timestamp']}');
  print('End Time: ${batchData['end_timestamp']}');
  
  DateTime start = DateTime.parse(batchData['start_timestamp']);
  DateTime end = DateTime.parse(batchData['end_timestamp']);
  double duration = end.difference(start).inMilliseconds / 1000.0;
  
  print('Calculated Duration: ${duration.toStringAsFixed(3)}s');
  print('Expected Duration: ~10s');
  print('Samples Array Length: ${(batchData['samples'] as List).length}');
  
  // Verify consistency
  int sampleCount = batchData['sample_count'];
  int arrayLength = (batchData['samples'] as List).length;
  double samplingRate = batchData['sampling_rate'];
  double expectedHz = arrayLength / duration;
  
  print('───────────────────────────────────────');
  print('VALIDATION:');
  print('  ✓ sample_count == array length? ${sampleCount == arrayLength ? "YES ✅" : "NO ❌"}');
  print('  ✓ sampling_rate correct? ${(samplingRate - expectedHz).abs() < 1 ? "YES ✅" : "NO ❌"}');
  print('  ✓ duration reasonable? ${(duration - 10).abs() < 1 ? "YES ✅" : "NO ❌"}');
  print('  ✓ Hz in range 200-600? ${samplingRate >= 200 && samplingRate <= 600 ? "YES ✅" : "NO ❌"}');
  print('═══════════════════════════════════════\n');
}
```

---

### **Test 2: Mock Data untuk Development**

```dart
Map<String, dynamic> createMockBatch(int sequence) {
  DateTime now = DateTime.now();
  DateTime start = now.subtract(Duration(seconds: 10));
  DateTime end = now;
  
  // Generate 4000 mock samples (10 detik @ 400 Hz)
  List<double> samples = List.generate(4000, (i) {
    // Simple sine wave for testing
    double t = i / 400.0; // Time in seconds
    return 0.5 * sin(2 * pi * 1.2 * t); // 1.2 Hz (72 BPM heart rate)
  });
  
  return {
    'batch_sequence': sequence,
    'sampling_rate': 400.0,
    'sample_count': 4000,
    'start_timestamp': start.toIso8601String(),
    'end_timestamp': end.toIso8601String(),
    'samples': samples,
  };
}
```

---

## 📊 **Expected vs Actual Values**

### **Target: 400 Hz, 10 detik**

| Parameter | Target | Acceptable Range | Not Acceptable |
|-----------|--------|------------------|----------------|
| **Sampling Rate** | 400 Hz | 320-480 Hz (±20%) | <200 Hz or >600 Hz |
| **Duration** | 10.0s | 9.5-10.5s | <9s or >11s |
| **Sample Count** | 4000 | 3800-4200 | <3000 or >5000 |
| **Timestamp Format** | ISO8601 | "2025-11-29T10:00:00.000Z" | Integer milliseconds |

---

## 🔍 **Cara Debug di Server**

### **Check di Rails Console:**

```ruby
# Login ke server
ssh user@server
cd /path/to/webapp
rails c

# Get recording terakhir
recording = Recording.last

# Check batch info
recording.biopotential_batches.ordered.each do |batch|
  puts "Batch #{batch.batch_sequence}:"
  puts "  Hz: #{batch.sample_rate}"
  puts "  Duration: #{batch.duration_seconds}s"
  puts "  Samples: #{batch.sample_count}"
  puts "  Start: #{batch.start_timestamp}"
  puts "  End: #{batch.end_timestamp}"
  puts "  Calculated Hz: #{batch.actual_sample_rate}"
  puts "---"
end
```

**Expected Output (Good):**
```
Batch 0:
  Hz: 398.5
  Duration: 10.03s
  Samples: 3998
  Start: 2025-11-29 10:00:00 UTC
  End: 2025-11-29 10:00:10 UTC
  Calculated Hz: 398.6
---
Batch 1:
  Hz: 401.2
  Duration: 9.97s
  Samples: 4002
  Start: 2025-11-29 10:00:10 UTC
  End: 2025-11-29 10:00:20 UTC
  Calculated Hz: 401.4
---
```

**Bad Output (Error):**
```
Batch 0:
  Hz: 22.4        ← ❌ TERLALU RENDAH!
  Duration: 178.5s ← ❌ DURASI SALAH (seharusnya ~10s)
  Samples: 4000
  Start: 2025-11-29 10:00:00 UTC
  End: 2025-11-29 10:02:58 UTC ← ❌ End timestamp salah!
  Calculated Hz: 22.4
---
```

---

## 🎯 **Checklist Implementation**

- [ ] **Duration calculation:** Convert milliseconds to seconds (`/ 1000.0`)
- [ ] **Timestamp format:** Use ISO8601 string (`toIso8601String()`)
- [ ] **Sample count:** Dynamic based on array length (`samples.length`)
- [ ] **Sampling rate:** Calculated from actual data (`samples.length / duration`)
- [ ] **Validation:** Check Hz range 200-600 before sending
- [ ] **Logging:** Print batch info untuk debug
- [ ] **Error handling:** Jangan kirim batch kalau Hz invalid
- [ ] **Testing:** Gunakan mock data untuk verify format

---

## 🚀 **Quick Implementation Template**

```dart
Future<Map<String, dynamic>?> collectAndPrepareBatch(int batchSequence) async {
  try {
    // 1. Start timing
    DateTime batchStart = DateTime.now();
    List<double> samples = [];
    const targetSamples = 4000;
    
    // 2. Collect samples
    while (samples.length < targetSamples) {
      double value = await readADCValue();
      samples.add(value);
      await Future.delayed(Duration(microseconds: 2500)); // ~400 Hz
    }
    
    // 3. End timing
    DateTime batchEnd = DateTime.now();
    
    // 4. Calculate duration (SECONDS!)
    double durationSeconds = batchEnd.difference(batchStart).inMilliseconds / 1000.0;
    
    // 5. Calculate actual Hz
    double actualHz = samples.length / durationSeconds;
    
    // 6. Validate
    if (actualHz < 200 || actualHz > 600) {
      print('❌ Invalid Hz: $actualHz - Batch not sent');
      return null;
    }
    
    // 7. Prepare data
    final batchData = {
      'batch_sequence': batchSequence,
      'sampling_rate': actualHz.roundToDouble(),
      'sample_count': samples.length,
      'start_timestamp': batchStart.toIso8601String(),
      'end_timestamp': batchEnd.toIso8601String(),
      'samples': samples,
    };
    
    // 8. Log & return
    print('✅ Batch $batchSequence ready: ${actualHz.toStringAsFixed(1)} Hz');
    return batchData;
    
  } catch (e) {
    print('❌ Error collecting batch: $e');
    return null;
  }
}
```

---

## 📞 **Contact & Support**

**Jika masih ada issue:**
1. Screenshot log output dari fungsi `logBatchInfo()`
2. Screenshot error dari Rails server (kalau ada)
3. Kirim ke backend team untuk analisa

**Backend akan validate:**
- ✅ Accept: 200-600 Hz
- ⚠️  Warning: Di luar 320-480 Hz (tapi tetap saved)
- ❌ Reject: <200 Hz atau >600 Hz (data corrupt)

---

**Last Updated:** November 29, 2025  
**Version:** 1.0  
**Status:** URGENT FIX - Data Corruption Issue
