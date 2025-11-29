# 🔄 Panduan Recovery Recording yang Stuck/Tergantung

## 📋 Daftar Isi
- [Problem Statement](#problem-statement)
- [Solusi Otomatis (Background Job)](#solusi-otomatis-background-job)
- [Solusi Manual (API Endpoints)](#solusi-manual-api-endpoints)
- [Cara Kerja Force Complete](#cara-kerja-force-complete)
- [Testing Guide](#testing-guide)
- [Monitoring & Alerts](#monitoring--alerts)

---

## Problem Statement

### Skenario Masalah

Recording bisa "stuck" dalam status `'recording'` jika:

1. **Mobile app crash** sebelum memanggil `/stop`
2. **Network connection lost** saat recording
3. **Patient emergency** (recording dihentikan mendadak)
4. **App force-closed** oleh user
5. **Battery died** saat recording

### Dampak

```
Status: 'recording' (SELAMANYA)
├─ ❌ Data EKG tersimpan tapi tidak bisa diakses
├─ ❌ Dokter tidak bisa lihat hasil
├─ ❌ QR code terpakai (is_used = true)
├─ ❌ Recording dianggap belum selesai
└─ ❌ Dashboard menampilkan recording "in progress" forever
```

---

## Solusi Otomatis (Background Job)

### Auto-Complete Job

File: [`app/jobs/auto_complete_stale_recordings_job.rb`](app/jobs/auto_complete_stale_recordings_job.rb)

**Strategi:**
- Jalan otomatis setiap **5 menit** (via cron/scheduler)
- Deteksi recording yang "stale"
- Auto-complete dengan data yang ada

**Kriteria Recording Stale:**

| Kondisi | Threshold | Action |
|---------|-----------|--------|
| Recording > 24 jam | Exceeded max duration | ✅ Auto-complete |
| Batch terakhir > 15 menit lalu | No recent activity | ✅ Auto-complete |
| Tidak ada batch & start > 15 menit | No data received | ✅ Auto-complete |

### Setup Background Job

#### Option 1: Using Whenever (Cron)

**Install:**
```bash
# Add to Gemfile
gem 'whenever', require: false

bundle install
wheneverize .
```

**Configure:** Edit `config/schedule.rb`
```ruby
# config/schedule.rb
every 5.minutes do
  runner "AutoCompleteStaleRecordingsJob.perform_now"
end
```

**Deploy:**
```bash
whenever --update-crontab
```

#### Option 2: Using Sidekiq (Recommended for Production)

**Install:**
```bash
# Add to Gemfile
gem 'sidekiq'
gem 'sidekiq-scheduler'

bundle install
```

**Configure:** Edit `config/sidekiq.yml`
```yaml
# config/sidekiq.yml
:schedule:
  auto_complete_stale_recordings:
    cron: '*/5 * * * *'  # Every 5 minutes
    class: AutoCompleteStaleRecordingsJob
    queue: default
```

**Start Sidekiq:**
```bash
bundle exec sidekiq
```

#### Option 3: Manual Trigger (For Testing)

**Rails Console:**
```ruby
rails c

# Run job manually
AutoCompleteStaleRecordingsJob.perform_now

# Check results
Recording.stale.count  # Should be 0 after job runs
```

---

## Solusi Manual (API Endpoints)

### 1. List Stale Recordings

**Endpoint:** `GET /api/recordings/stale`

**Purpose:** Melihat recording yang stuck

**Request:**
```bash
curl -X GET http://localhost:3000/api/recordings/stale \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -H "Content-Type: application/json"
```

**Query Parameters:**
- `threshold_minutes` (optional, default: 15) - Minimum waktu sejak aktivitas terakhir

**Response:**
```json
{
  "success": true,
  "message": "Found 2 stale recordings",
  "threshold_minutes": 15,
  "data": [
    {
      "id": 123,
      "session_id": "702664379c264e04",
      "status": "recording",
      "started_at": "2025-11-29T10:00:00Z",
      "duration_since_start_minutes": 45,
      "has_batch_data": true,
      "total_batches": 12,
      "total_samples": 60000,
      "last_batch_at": "2025-11-29T10:12:00Z",
      "minutes_since_last_batch": 33,
      "patient": {
        "id": 456,
        "name": "John Doe",
        "identifier": "PAT001"
      }
    }
  ]
}
```

---

### 2. Force Complete Recording

**Endpoint:** `POST /api/recordings/:id/force_complete`

**Purpose:** Manually complete recording yang stuck

**Request:**
```bash
curl -X POST http://localhost:3000/api/recordings/123/force_complete \
  -H "Content-Type: application/json" \
  -d '{
    "reason": "Patient emergency - recording interrupted"
  }'
```

**Response:**
```json
{
  "success": true,
  "message": "Recording berhasil di-force complete",
  "data": {
    "recording_id": 123,
    "session_id": "702664379c264e04",
    "status": "completed",
    "started_at": "2025-11-29T10:00:00Z",
    "ended_at": "2025-11-29T10:12:00Z",
    "duration_seconds": 720,
    "total_samples": 60000,
    "total_batches": 12,
    "data_status": "complete",
    "notes": "[Force-completed at 2025-11-29T10:45:00Z]\nReason: Patient emergency - recording interrupted\nData saved up to: 2025-11-29T10:12:00.000Z\nTotal batches: 12\nTotal samples: 60000"
  }
}
```

---

## Cara Kerja Force Complete

### Logic Flow

```ruby
def force_complete!(reason: nil)
  # 1. Determine end_time
  end_time = if has_batch_data?
    # Use last batch timestamp
    last_batch = biopotential_batches.order(end_timestamp: :desc).first
    last_batch.end_timestamp
  else
    # No data, use start_time + 1 second
    start_time + 1.second
  end
  
  # 2. Calculate duration
  duration_seconds = (end_time - start_time).to_i
  
  # 3. Update recording
  update!(
    status: 'completed',
    end_time: end_time,
    duration_seconds: duration_seconds,
    notes: "[Auto-metadata]"
  )
end
```

### Metadata yang Ditambahkan

Force complete akan menambahkan notes otomatis:

```
[Force-completed at 2025-11-29T10:45:00Z]
Reason: Patient emergency - recording interrupted
Data saved up to: 2025-11-29T10:12:00.000Z
Total batches: 12
Total samples: 60000
```

---

## Testing Guide

### Test 1: Simulate Stuck Recording

```bash
# 1. Start recording
RECORDING_ID=$(curl -s -X POST http://localhost:3000/api/recordings/start \
  -H "Content-Type: application/json" \
  -d '{"session_id": "test_session_123", "sample_rate": 500.0}' \
  | jq -r '.data.recording_id')

echo "Recording ID: $RECORDING_ID"

# 2. Send 2 batches
curl -X POST http://localhost:3000/api/recordings/data \
  -H "Content-Type: application/json" \
  -d "{
    \"recording_id\": $RECORDING_ID,
    \"batch_data\": {
      \"batch_sequence\": 0,
      \"start_timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%S.000Z)\",
      \"end_timestamp\": \"$(date -u -d '+10 seconds' +%Y-%m-%dT%H:%M:%S.000Z)\",
      \"sample_rate\": 500.0,
      \"samples\": $(python3 -c 'import json; print(json.dumps([0.5 + i*0.001 for i in range(5000)]))')
    }
  }"

# 3. DON'T CALL /stop (simulate crash)

# 4. Check if recording is stuck
curl -s http://localhost:3000/api/recordings/$RECORDING_ID | jq '.data.recording.status'
# Output: "recording"

# 5. Wait 15+ minutes OR manually trigger job
rails runner "AutoCompleteStaleRecordingsJob.perform_now"

# 6. Check status again
curl -s http://localhost:3000/api/recordings/$RECORDING_ID | jq '.data.recording.status'
# Output: "completed"
```

### Test 2: Manual Force Complete

```bash
# Get recording ID that's stuck
RECORDING_ID=123

# Force complete it
curl -X POST http://localhost:3000/api/recordings/$RECORDING_ID/force_complete \
  -H "Content-Type: application/json" \
  -d '{
    "reason": "Testing manual force complete"
  }' | jq '.'

# Verify it's completed
curl -s http://localhost:3000/api/recordings/$RECORDING_ID \
  | jq '.data.recording | {status, ended_at, duration_seconds, total_samples}'
```

### Test 3: List Stale Recordings

```bash
# Create JWT token first (if needed)
TOKEN="your_jwt_token"

# List stale recordings
curl -X GET "http://localhost:3000/api/recordings/stale?threshold_minutes=10" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  | jq '.'
```

---

## Monitoring & Alerts

### Rails Console Queries

**Check stale recordings:**
```ruby
# Find recordings stuck for > 15 minutes
Recording.stale(15).each do |r|
  puts "ID: #{r.id}, Started: #{r.start_time}, Last batch: #{r.biopotential_batches.last&.created_at}"
end

# Count by status
Recording.group(:status).count

# Check recordings from today
Recording.where('start_time > ?', Date.today).group(:status).count
```

**Manually complete stale recordings:**
```ruby
# Complete all stale recordings
Recording.stale(15).each do |recording|
  recording.force_complete!(reason: 'Manual cleanup via console')
  puts "✓ Completed recording ##{recording.id}"
end
```

### Logging

Background job will log to `log/production.log`:

```
[AutoCompleteStaleRecordings] Starting job...
[AutoCompleteStaleRecordings] Found 2 stale recordings
[Stale Check] Recording #123: No batch received in 15 minutes (last: 2025-11-29 10:12:00 UTC)
[Complete] Recording #123 auto-completed: duration=720s, samples=60000, batches=12
[AutoCompleteStaleRecordings] ✓ Completed recording #123
[AutoCompleteStaleRecordings] Completed: 2, Failed: 0
```

### Dashboard Integration (Optional)

Add to admin dashboard:

```erb
<!-- app/views/dashboard/superuser_dashboard.html.erb -->
<div class="card">
  <div class="card-header">
    <h5>Stale Recordings (Stuck > 15 min)</h5>
  </div>
  <div class="card-body">
    <% stale_count = Recording.stale(15).count %>
    <% if stale_count > 0 %>
      <div class="alert alert-warning">
        ⚠️ <%= stale_count %> recording(s) stuck in 'recording' status
        <%= link_to 'View Details', api_recordings_stale_path, class: 'btn btn-sm btn-warning' %>
      </div>
    <% else %>
      <p class="text-success">✓ No stale recordings</p>
    <% end %>
  </div>
</div>
```

---

## Summary / Checklist

### For Development:

- [ ] Install background job gem (Sidekiq or Whenever)
- [ ] Configure scheduler for `AutoCompleteStaleRecordingsJob`
- [ ] Test manual force complete via API
- [ ] Test auto-complete via background job
- [ ] Add monitoring dashboard (optional)

### For Production:

- [ ] Deploy background job worker (Sidekiq/cron)
- [ ] Set up job monitoring (Sidekiq Web UI)
- [ ] Configure alerts for failed jobs
- [ ] Document process for support team
- [ ] Add Slack/email notification for stale recordings (optional)

### For Support Team:

**When user reports "recording stuck":**

1. Check if recording exists and is stuck:
   ```bash
   curl -X GET http://api.example.com/api/recordings/stale \
     -H "Authorization: Bearer TOKEN"
   ```

2. Manually force complete:
   ```bash
   curl -X POST http://api.example.com/api/recordings/{ID}/force_complete \
     -H "Content-Type: application/json" \
     -d '{"reason": "User reported stuck recording"}'
   ```

3. Verify completion:
   ```bash
   curl -X GET http://api.example.com/api/recordings/{ID}
   ```

---

## FAQ

**Q: Berapa lama threshold yang aman untuk auto-complete?**  
A: Default 15 menit. Bisa disesuaikan di `AutoCompleteStaleRecordingsJob::STALE_THRESHOLD_MINUTES`

**Q: Apakah data EKG akan hilang saat force complete?**  
A: Tidak. Data batch yang sudah masuk akan tetap tersimpan. Force complete hanya mengubah status dan set end_time.

**Q: Apakah bisa recovery data setelah force complete?**  
A: Ya, mobile app masih bisa kirim data via `/recover_data` endpoint setelah recording completed.

**Q: Bagaimana jika recording tidak punya batch data sama sekali?**  
A: Recording akan tetap di-complete dengan `duration_seconds = 1` dan `total_samples = 0`. Dokter akan melihat warning "No data".

**Q: Apakah QR code bisa dipakai lagi setelah force complete?**  
A: Tidak. QR code tetap `is_used = true`. Harus generate QR code baru untuk recording berikutnya.

---

**Last Updated:** November 29, 2025  
**Version:** 1.0  
**Status:** Production Ready
