# 🐛 Debugging: Data Tidak Muncul di Grafik

## 🔍 Checklist Debugging

### 1. **Check Recording Data Exists**

```bash
# Rails console
rails c

# Check recording
recording = Recording.find(YOUR_RECORDING_ID)
recording.biopotential_batches.count  # Should be > 0
recording.total_samples               # Should be > 0

# Check batch timestamps
batches = recording.biopotential_batches.ordered.limit(3)
batches.each do |b|
  puts "Batch #{b.batch_sequence}: #{b.start_timestamp} -> #{b.end_timestamp}"
  puts "  Samples: #{b.sample_count}"
end
```

### 2. **Check Browser Console Log**

Buka Chrome DevTools (F12) → Console tab

Look for:
```javascript
Fetching data: {
  recording_id: 123,
  start_time: "2025-11-24T06:05:12.657Z",
  end_time: "2025-11-24T06:06:02.657Z",
  url: "/recordings/123/data?start_time=..."
}

Received data: {
  type: "raw",
  data: [...],  // Should have data!
  meta: { sample_count: 10000 }  // Should be > 0
}
```

**Problem Signs:**
- ❌ `data: []` (empty array)
- ❌ `sample_count: 0`
- ❌ No console log at all

### 3. **Check Rails Server Log**

```bash
tail -f log/development.log
```

Look for:
```
Data request - Recording: 123, Start: 2025-11-24 13:05:12, End: 2025-11-24 13:06:02
Recording time range: 2025-11-22 13:05:12 to 2025-11-22 14:05:12
Found 6 batches for time range
Total samples estimate: 30000
Downsampling: 30000 samples -> target 10000 (skip=3)
```

**Problem Signs:**
- ❌ `Found 0 batches` → Time range mismatch
- ❌ `Total samples estimate: 0` → No samples in batches

---

## 🔧 Common Issues & Fixes

### Issue 1: Time Zone Mismatch

**Symptom:**
```json
{
  "data": [],
  "meta": { "sample_count": 0 }
}
```

**Cause:** Browser sends UTC time, but batch timestamps in different timezone

**Debug:**
```ruby
# Rails console
recording = Recording.find(123)
recording.start_time  # Check timezone
batch = recording.biopotential_batches.first
batch.start_timestamp  # Should match timezone
```

**Fix:** Already handled in controller with `Time.zone.parse()`

---

### Issue 2: Scope Filter Too Strict

**Symptom:** Log shows `Found 0 batches` even though batches exist

**Cause:** `by_time_range` scope doesn't find overlapping batches

**Old (Wrong) Code:**
```ruby
# This only finds batches FULLY WITHIN the range
scope :by_time_range, ->(start_time, end_time) { 
  where('start_timestamp >= ? AND end_timestamp <= ?', start_time, end_time) 
}
```

**New (Fixed) Code:**
```ruby
# This finds batches that OVERLAP with the range
scope :by_time_range, ->(start_time, end_time) { 
  where('start_timestamp <= ? AND end_timestamp >= ?', end_time, start_time) 
}
```

**Explanation:**
```
Request Range:    |----------|
Batch 1:      |-----|          ✅ Overlaps (batch_start < range_end)
Batch 2:               |-----|  ✅ Overlaps (batch_end > range_start)
Batch 3:  |---|                ❌ No overlap
Batch 4:                  |--- ❌ No overlap
```

---

### Issue 3: No Initial Data Fetch

**Symptom:** Chart appears but empty, no console logs

**Cause:** JavaScript not calling `fetchDataBuffered()` on init

**Check:**
```javascript
// In view_recording.html.erb
document.addEventListener('DOMContentLoaded', function() {
  initChart();
  
  if (HAS_DATA) {  // ← Check this condition
    fetchDataBuffered(START_TIME, Math.min(START_TIME + INITIAL_WINDOW, RECORDING_END_TIME));
  }
});
```

**Fix:** Ensure `HAS_DATA = true` or remove condition

---

### Issue 4: Recording Start Time Wrong

**Symptom:** Data exists but query uses wrong time

**Debug:**
```ruby
recording = Recording.find(123)
puts "start_time: #{recording.start_time}"
puts "created_at: #{recording.created_at}"

# Check first batch
batch = recording.biopotential_batches.ordered.first
puts "First batch: #{batch.start_timestamp}"

# They should match (approximately)
```

**Fix:**
```ruby
# Controller uses start_time if available, else created_at
recording_start = @recording.start_time || @recording.created_at
```

---

### Issue 5: Data Cached as Empty

**Symptom:** Data appears after refresh, but not after fix

**Cause:** Browser cached empty response

**Fix:**
```javascript
// In browser console
dataCache = {};  // Clear cache
location.reload();  // Reload page
```

Or force-refresh: `Ctrl+Shift+R` (Windows/Linux) or `Cmd+Shift+R` (Mac)

---

## 🧪 Manual Test

### Test 1: Direct API Call

```bash
# Get recording start time
RECORDING_ID=123
START_TIME="2025-11-22T06:00:00.000Z"
END_TIME="2025-11-22T07:00:00.000Z"

# Call API
curl "http://localhost:3000/recordings/${RECORDING_ID}/data?start_time=${START_TIME}&end_time=${END_TIME}" | jq

# Expected:
{
  "type": "raw",
  "data": [
    {"x": 1732248000000, "y": 0.523},
    {"x": 1732248002000, "y": 0.481},
    ...
  ],
  "meta": {
    "sample_count": 10000,
    "recording_status": "completed"
  }
}
```

### Test 2: Check Batch Data

```bash
rails c

recording = Recording.find(123)
batch = recording.biopotential_batches.first

# Check batch has samples
batch.samples.size  # Should be 5000
batch.samples.first  # Should be a number (float)

# Check timestamps
batch.start_timestamp  # Should be valid datetime
batch.end_timestamp    # Should be after start_timestamp
```

### Test 3: Check Scope Works

```bash
rails c

recording = Recording.find(123)
start_time = recording.start_time
end_time = start_time + 10.seconds

# Should find first batch
batches = recording.biopotential_batches.by_time_range(start_time, end_time)
batches.count  # Should be >= 1
```

---

## 📊 Expected Flow (Working)

```
1. Page Load
   └─> JavaScript: DOMContentLoaded
       └─> initChart() ✅
       └─> fetchDataBuffered(START_TIME, START_TIME + 10s) ✅
           └─> Console: "Fetching data: {recording_id: 123, ...}"

2. Server Request
   └─> Rails: RecordingsController#data
       └─> Log: "Data request - Recording: 123"
       └─> Query batches with by_time_range scope ✅
       └─> Log: "Found 6 batches"
       └─> Log: "Total samples estimate: 30000"
       └─> Downsample to 10K points ✅
       └─> Return JSON ✅

3. Client Update
   └─> JavaScript: updateChartData()
       └─> Console: "Received data: {type: 'raw', data: [...]}"
       └─> Update chart.data.datasets[0].data ✅
       └─> Chart renders ✅ 📈
```

---

## 🚨 Red Flags in Logs

| Log Message | Meaning | Action |
|-------------|---------|--------|
| `Found 0 batches` | No batches match query | Check timestamps |
| `Total samples estimate: 0` | Batches have no samples | Check batch.data |
| `Downsampling: 0 samples` | No data to process | Check database |
| `data: []` in browser | Empty response | Check all above |
| No logs at all | Request not reaching server | Check route/URL |

---

## ✅ Quick Fix Checklist

- [ ] Run `rails db:seed` to create test data
- [ ] Check `Recording.find(id).biopotential_batches.count > 0`
- [ ] Check browser console for logs
- [ ] Check rails log for "Data request"
- [ ] Clear browser cache (`dataCache = {}`)
- [ ] Try direct API call with curl
- [ ] Check timezone of timestamps
- [ ] Restart Rails server if needed

---

## 📝 Notes

**Why was it broken?**
The `by_time_range` scope was too restrictive. It only found batches that were **completely inside** the requested range, but we need batches that **overlap** with the range.

**Fix Applied:**
Changed from:
```ruby
# Only finds batch if: batch_start >= range_start AND batch_end <= range_end
where('start_timestamp >= ? AND end_timestamp <= ?', start_time, end_time)
```

To:
```ruby
# Finds batch if: batch_start <= range_end AND batch_end >= range_start
where('start_timestamp <= ? AND end_timestamp >= ?', end_time, start_time)
```

This is the correct overlap detection formula! ✅
