# ⏱️ Grace Period Logic - Smart Recording Termination

## 📋 Overview

Sistem ini menggunakan **grace period proporsional** untuk menentukan kapan recording harus otomatis di-terminate. Grace period disesuaikan dengan durasi recording agar tidak terlalu ketat atau terlalu longgar.

---

## 🎯 Konsep Dasar

### Problem yang Diselesaikan

**Skenario:**
- Recording max_duration = 1 jam (60 menit)
- Mobile app kehilangan koneksi internet selama 30 menit
- App reconnect dan kirim data lagi

**Tanpa grace period:**
- ❌ Recording langsung di-terminate saat lewat 60 menit
- ❌ Data dari menit 61-90 ditolak
- ❌ Pasien harus mulai recording baru

**Dengan grace period (proporsional):**
- ✅ Recording diberi toleransi +10 menit (grace period)
- ✅ Total allowed: 60 + 10 = 70 menit
- ✅ Data dari menit 61-70 masih diterima
- ✅ Auto-terminate hanya setelah 70 menit

---

## 📊 Grace Period Table

| Max Duration | Range | Grace Period | Total Allowed | Ratio |
|--------------|-------|--------------|---------------|-------|
| 1 minute | 0-1 min | 1 minute | 2 minutes | 100% |
| 5 minutes | 1-5 min | 1 minute | 6 minutes | 20% |
| 10 minutes | 5-10 min | 2 minutes | 12 minutes | 20% |
| 30 minutes | 10-30 min | 5 minutes | 35 minutes | 16.7% |
| 60 minutes | 30-60 min | 10 minutes | 70 minutes | 16.7% |
| 90 minutes | 1-2 hours | 15 minutes | 105 minutes | 16.7% |
| 3 hours | 2-4 hours | 30 minutes | 210 minutes | 16.7% |
| 8 hours | > 4 hours | 1 hour | 9 hours | 12.5% |
| 24 hours | > 4 hours | 1 hour | 25 hours | 4.2% |

---

## 💻 Implementation

### Model Method: `calculate_grace_period`

File: [`app/models/recording.rb`](app/models/recording.rb)

```ruby
def calculate_grace_period(duration_seconds)
  case duration_seconds
  when 0..60          # <= 1 minute: grace = 1 minute
    60
  when 61..300        # 1-5 minutes: grace = 1 minute
    60
  when 301..600       # 5-10 minutes: grace = 2 minutes
    120
  when 601..1800      # 10-30 minutes: grace = 5 minutes
    300
  when 1801..3600     # 30-60 minutes: grace = 10 minutes
    600
  when 3601..7200     # 1-2 hours: grace = 15 minutes
    900
  when 7201..14400    # 2-4 hours: grace = 30 minutes
    1800
  else                # > 4 hours: grace = 1 hour
    3600
  end
end
```

---

## 🔍 Check Logic

### Method: `exceeded_max_duration?`

```ruby
def exceeded_max_duration?
  return false unless status == 'recording'
  return false unless start_time
  return false unless qr_code&.duration_in_seconds
  
  max_duration = qr_code.duration_in_seconds
  grace_period = calculate_grace_period(max_duration)
  total_allowed = max_duration + grace_period
  
  elapsed = Time.current - start_time
  elapsed > total_allowed
end
```

**Checks performed:**
1. Recording masih dalam status `'recording'`?
2. Ada `start_time`?
3. QR code punya `max_duration_minutes`?
4. Elapsed time > (max_duration + grace_period)?

---

## 🚀 Auto-Complete Workflow

### Trigger Points (Lazy Evaluation)

Auto-complete dipanggil saat:

1. **POST /api/recordings/data** (setiap batch dikirim)
   ```ruby
   if @recording.exceeded_max_duration?
     @recording.auto_complete_if_exceeded!
     return error_response
   end
   ```

2. **GET /api/recordings/:id** (saat fetch recording detail)
   ```ruby
   if @recording.exceeded_max_duration?
     @recording.auto_complete_if_exceeded!
     @recording.reload
   end
   ```

3. **GET /api/recordings** (saat list recordings)
   ```ruby
   recordings.each do |recording|
     if recording.exceeded_max_duration?
       recording.auto_complete_if_exceeded!
       recording.reload
     end
   end
   ```

4. **Background Job** (setiap 5 menit via cron/Sidekiq)
   ```ruby
   AutoCompleteStaleRecordingsJob.perform_now
   ```

---

## 📝 Metadata yang Ditambahkan

Saat auto-complete, sistem menambahkan notes:

```
[Force-completed at 2025-11-29T15:30:00Z]
Reason: Recording exceeded maximum duration | Max duration: 60 minutes | Grace period: 10 minutes | Auto-completed by system
Data saved up to: 2025-11-29T15:10:00.000Z
Total batches: 72
Total samples: 360000
```

---

## 🧪 Testing Examples

### Example 1: Recording 1 Hour (60 minutes)

```ruby
# Setup
qr_code = QrCode.create!(max_duration_minutes: 60) # 3600 seconds
recording = Recording.create!(qr_code: qr_code, start_time: 60.minutes.ago)

# Calculate
max_duration = 3600 # 60 minutes
grace_period = recording.calculate_grace_period(max_duration) # 600 (10 minutes)
total_allowed = 3600 + 600 # 70 minutes

# Check
elapsed = Time.current - recording.start_time # 60 minutes (3600 seconds)
recording.exceeded_max_duration? # false (60 < 70)

# After 71 minutes
recording.update(start_time: 71.minutes.ago)
recording.exceeded_max_duration? # true (71 > 70)
```

### Example 2: Recording 5 Minutes

```ruby
# Setup
qr_code = QrCode.create!(max_duration_minutes: 5) # 300 seconds
recording = Recording.create!(qr_code: qr_code, start_time: 5.minutes.ago)

# Calculate
max_duration = 300 # 5 minutes
grace_period = recording.calculate_grace_period(max_duration) # 60 (1 minute)
total_allowed = 300 + 60 # 6 minutes

# Check at 5.5 minutes
recording.update(start_time: 5.5.minutes.ago)
recording.exceeded_max_duration? # false (5.5 < 6)

# Check at 7 minutes
recording.update(start_time: 7.minutes.ago)
recording.exceeded_max_duration? # true (7 > 6)
```

### Example 3: Recording 24 Hours

```ruby
# Setup
qr_code = QrCode.create!(max_duration_minutes: 1440) # 86400 seconds (24 hours)
recording = Recording.create!(qr_code: qr_code, start_time: 24.hours.ago)

# Calculate
max_duration = 86400 # 24 hours
grace_period = recording.calculate_grace_period(max_duration) # 3600 (1 hour)
total_allowed = 86400 + 3600 # 25 hours

# Check at 24.5 hours
recording.update(start_time: 24.5.hours.ago)
recording.exceeded_max_duration? # false (24.5 < 25)

# Check at 26 hours
recording.update(start_time: 26.hours.ago)
recording.exceeded_max_duration? # true (26 > 25)
```

---

## 🔄 Complete Flow Example

### Scenario: 1-hour Recording with Network Loss

```
Time  | Event                                  | Status      | Action
------|----------------------------------------|-------------|---------------------------
00:00 | POST /start (max_duration=60min)      | recording   | Start time: 10:00
00:10 | POST /data (batch 0)                  | recording   | ✅ Accepted
00:20 | POST /data (batch 1)                  | recording   | ✅ Accepted
00:30 | [Network lost - no data for 30 min]   | recording   | ⏳ Waiting...
01:00 | System check: exceeded?               | recording   | ❌ No (60 < 70)
01:05 | [Network restored]                    | recording   | 
01:05 | POST /data (batch 2)                  | recording   | ✅ Accepted (65 < 70)
01:10 | POST /data (batch 3)                  | recording   | ✅ Accepted (70 = 70)
01:15 | POST /data (batch 4) - REJECTED       | completed   | ❌ Auto-completed!
      |                                        |             | end_time: 11:10
      |                                        |             | duration: 70 minutes
```

**Error Response at 01:15:**
```json
{
  "success": false,
  "error": "Recording sudah melebihi durasi maksimum",
  "message": "Recording telah otomatis di-complete karena melebihi max_duration + grace period",
  "current_status": "completed",
  "max_duration_minutes": 60,
  "grace_period_minutes": 10
}
```

---

## 📱 Mobile App Handling

### Recommended Strategy

```dart
Future<void> sendBatch(Map<String, dynamic> batchData) async {
  final response = await http.post(
    Uri.parse('$baseUrl/api/recordings/data'),
    body: jsonEncode({
      'recording_id': recordingId,
      'batch_data': batchData,
    }),
  );
  
  if (response.statusCode == 422) {
    final data = jsonDecode(response.body);
    if (data['error'] == 'Recording sudah melebihi durasi maksimum') {
      // Recording auto-completed by server
      print('⚠️ Recording terminated: ${data['message']}');
      print('Max duration: ${data['max_duration_minutes']} minutes');
      print('Grace period: ${data['grace_period_minutes']} minutes');
      
      // Stop local recording
      await stopLocalRecording();
      
      // Show notification to user
      showNotification('Recording selesai (melebihi durasi maksimum)');
    }
  }
}
```

---

## ⚙️ Configuration

### Adjust Grace Period Logic

Edit [`app/models/recording.rb`](app/models/recording.rb):

```ruby
def calculate_grace_period(duration_seconds)
  # Customize these values based on requirements
  case duration_seconds
  when 0..60
    60  # Change from 1 minute to 30 seconds: 30
  when 61..300
    60  # Keep 1 minute
  # ... etc
  end
end
```

### Disable Auto-Complete (Not Recommended)

Comment out checks in controller:

```ruby
# POST /api/recordings/data
def data
  # if @recording.exceeded_max_duration?
  #   @recording.auto_complete_if_exceeded!
  #   return error_response
  # end
  
  # ... rest of code
end
```

---

## 🎯 Benefits

| Feature | Before | After |
|---------|--------|-------|
| **Network Loss Tolerance** | ❌ Immediate reject | ✅ Grace period buffer |
| **Proportional Grace** | ❌ Fixed timeout | ✅ Smart scaling |
| **Short Recordings** | ❌ Too lenient | ✅ Appropriate grace |
| **Long Recordings** | ❌ Too strict | ✅ Reasonable buffer |
| **No Background Job** | ❌ Required cron | ✅ Lazy evaluation |
| **Battery Efficient** | ❌ Constant polling | ✅ Check on-demand |

---

## 🐛 Debugging

### Check Recording Status

```ruby
rails c

# Get recording
recording = Recording.find(123)

# Check if exceeded
recording.exceeded_max_duration?
# => true/false

# Get details
max = recording.qr_code.duration_in_seconds
grace = recording.calculate_grace_period(max)
elapsed = Time.current - recording.start_time

puts "Max duration: #{max / 60} minutes"
puts "Grace period: #{grace / 60} minutes"
puts "Total allowed: #{(max + grace) / 60} minutes"
puts "Elapsed: #{elapsed / 60} minutes"
puts "Exceeded: #{elapsed > (max + grace)}"
```

### Force Complete Test

```ruby
recording = Recording.find(123)
recording.auto_complete_if_exceeded!
recording.reload
recording.status # => "completed"
```

---

## 📊 Monitoring

### Query Recordings Near Limit

```ruby
# Find recordings approaching grace period limit
Recording.recording.select do |r|
  next unless r.qr_code
  max = r.qr_code.duration_in_seconds
  grace = r.calculate_grace_period(max)
  elapsed = Time.current - r.start_time
  
  # Within 5 minutes of limit
  (elapsed > (max + grace - 300)) && (elapsed < (max + grace))
end
```

### Stats by Duration Range

```ruby
# Group by max_duration
Recording.completed.joins(:qr_code).group('qr_codes.max_duration_minutes').count

# Average grace period used
Recording.completed.map do |r|
  next unless r.qr_code && r.duration_seconds
  max = r.qr_code.duration_in_seconds
  actual = r.duration_seconds
  grace_used = actual - max
  [r.id, grace_used / 60] if grace_used > 0
end.compact
```

---

## 📞 FAQ

**Q: Kenapa tidak pakai fixed timeout 15 menit untuk semua?**  
A: Recording 1 menit dengan grace 15 menit = 1500% overhead (boros).  
   Recording 24 jam dengan grace 15 menit = 1% overhead (terlalu ketat).

**Q: Apakah grace period bisa di-customize per hospital/patient?**  
A: Saat ini belum, tapi bisa ditambahkan field `grace_period_multiplier` di QR code atau Hospital model.

**Q: Bagaimana jika mobile app force-close di tengah grace period?**  
A: Background job akan tetap auto-complete setelah grace period habis.

**Q: Apakah data yang dikirim dalam grace period akan disimpan?**  
A: Ya, selama masih dalam grace period, data akan diterima dan disimpan normal.

**Q: Bagaimana cara disable grace period untuk testing?**  
A: Set semua return value di `calculate_grace_period` menjadi `0`.

---

**Last Updated:** November 29, 2025  
**Version:** 1.0  
**Status:** Production Ready ✅
