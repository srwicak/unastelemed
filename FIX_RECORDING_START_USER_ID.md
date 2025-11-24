# Fix: Recording Start API - Foreign Key Constraint Violation

## Masalah
API `/api/recordings/start` mengalami error 500 dengan ROLLBACK transaction karena foreign key constraint violation pada kolom `user_id`.

### Root Cause
Mobile app mengirim `user_id: 8` yang tidak ada di database, menyebabkan foreign key constraint error saat membuat recording baru.

```
Recording Create (5.3ms)  INSERT INTO "recordings" (..., "user_id") VALUES (..., 8) RETURNING "id"
TRANSACTION (0.7ms)  ROLLBACK
```

## Solusi
Mengubah logika assignment `user_id` untuk **memprioritaskan `qr_code.healthcare_provider_id`** sebagai sumber utama, karena:

1. QR code sudah divalidasi dan healthcare_provider_id dijamin ada
2. Mobile app mungkin mengirim user_id yang tidak valid/tidak sinkron

### Kode Sebelumnya
```ruby
@recording = Recording.create!(
  patient_id: qr_code.patient_id,
  hospital_id: qr_code.hospital_id,
  user_id: user_id || qr_code.healthcare_provider_id,  # ❌ Prioritas salah
  ...
)
```

### Kode Sesudahnya
```ruby
# Use QR code's healthcare_provider_id as the primary source for user_id
# since it's validated and guaranteed to exist
recording_user_id = if qr_code.healthcare_provider_id == 'User'
  qr_code.healthcare_provider_id
else
  # If healthcare_provider is MedicalStaff, get their associated user_id
  medical_staff = MedicalStaff.find_by(id: qr_code.healthcare_provider_id)
  medical_staff&.user_id || user_id
end

@recording = Recording.create!(
  patient_id: qr_code.patient_id,
  hospital_id: qr_code.hospital_id,
  user_id: recording_user_id,  # ✅ Menggunakan ID yang valid
  ...
)
```

## Testing
Untuk menguji fix ini:

```bash
# 1. Cek QR code yang ada
rails runner "qr = QrCode.joins(:recording_session).find_by(recording_sessions: {session_id: 'session_50c4be7a78c39d03a47866ed'}); puts qr.inspect"

# 2. Test API dengan curl
curl -X POST http://localhost:3000/api/recordings/start \
  -H "Content-Type: application/json" \
  -d '{
    "recording": {
      "user_id": "999",
      "device_id": "B8:F8:62:D8:6D:D1",
      "qr_session_id": "session_50c4be7a78c39d03a47866ed",
      "start_time": "2025-11-23T11:26:15.409351Z"
    }
  }'
```

Seharusnya sekarang API berhasil membuat recording meskipun `user_id: 999` tidak ada, karena akan menggunakan `qr_code.healthcare_provider_id` yang valid.

## File yang Diubah
- `app/controllers/api/recordings_controller.rb` (lines 201-219)

## Tanggal
2025-11-23
