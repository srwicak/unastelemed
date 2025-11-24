# Dokumentasi Implementasi Fitur Baru

## Tanggal: 22 November 2025

## 📋 Ringkasan Perubahan

Implementasi telah berhasil menambahkan fitur-fitur yang diperlukan untuk:
1. ✅ QR Code dengan payload lengkap sesuai kebutuhan aplikasi mobile
2. ✅ Sistem registrasi dan approval untuk tenaga medis (dokter/perawat)
3. ✅ Integrasi lengkap antara RecordingSession dan QrCode

---

## 🔧 Perubahan Database

### 1. **Recording Sessions**
**Migration:** `20251122010139_add_session_id_to_recording_sessions.rb`

```ruby
# Kolom baru:
- session_id (string, unique) - ID unik untuk setiap sesi pemeriksaan
```

**Fungsi:** Memberikan identifier unik untuk setiap sesi yang dapat digunakan oleh aplikasi mobile.

### 2. **QR Codes**
**Migration:** `20251122010146_add_recording_session_id_to_qr_codes.rb`

```ruby
# Kolom baru:
- recording_session_id (references) - Foreign key ke recording_sessions
```

**Fungsi:** Menghubungkan QR code langsung dengan sesi pemeriksaan.

### 3. **Medical Staffs**
**Migration:** `20251122010153_add_approval_fields_to_medical_staffs.rb`

```ruby
# Kolom baru:
- approval_status (string, default: 'pending') - Status approval: pending/approved/rejected
- approved_by (integer) - ID user yang melakukan approval
- approved_at (datetime) - Timestamp approval
```

**Fungsi:** Sistem approval untuk pendaftaran tenaga medis baru.

---

## 📱 QR Code Payload Baru

### Format Payload untuk Aplikasi Mobile:

```json
{
  "code": "a1b2c3d4e5f6...",
  "hospital_id": 1,
  "healthcare_provider_id": 5,
  "healthcare_provider_type": "User",
  "valid_until": "2025-11-23T10:30:00Z",
  "max_duration_minutes": 60,
  "durasi": 3600,
  "timestamp": "2025-11-22T10:30:00Z",
  "patient_identifier": "user_12345",
  "session_id": "session_abc123def456"
}
```

### Field yang Ditambahkan:
- ✅ **patient_identifier** - Identifier unik pasien dari model Patient
- ✅ **session_id** - ID unik sesi pemeriksaan
- ✅ **durasi** - Durasi dalam detik (konversi dari max_duration_minutes)
- ✅ **timestamp** - Waktu pembuatan QR code (ISO 8601)

### Lokasi Implementasi:
**File:** `app/models/qr_code.rb`

**Method:** `qr_payload`

```ruby
def qr_payload
  payload = {
    code: code,
    hospital_id: hospital_id,
    healthcare_provider_id: healthcare_provider_id,
    healthcare_provider_type: healthcare_provider_type,
    valid_until: valid_until.iso8601,
    max_duration_minutes: max_duration_minutes,
    durasi: duration_in_seconds,
    timestamp: created_at.iso8601
  }
  
  # Tambahkan patient_identifier jika patient adalah Patient model
  if patient_type == 'Patient' && patient.present?
    payload[:patient_identifier] = patient.patient_identifier
  end
  
  # Tambahkan session_id jika terhubung ke recording_session
  if recording_session.present?
    payload[:session_id] = recording_session.session_id
  end
  
  payload.to_json
end
```

---

## 👥 Sistem Registrasi Tenaga Medis

### Alur Pendaftaran:

```
1. Dokter/Perawat → Buka halaman registrasi
2. Isi form dengan:
   - Email & Password
   - Posisi (Dokter/Perawat)
   - Nama Lengkap
   - Nomor Izin Praktik (SIP/STR)
   - Spesialisasi
   - Pilih Rumah Sakit
3. Submit → Status: PENDING
4. Hospital Manager → Review pendaftaran
5. Approve/Reject → Status: APPROVED/REJECTED
6. User menerima notifikasi (TODO: Email)
```

### URL & Routes:

```ruby
# Registrasi
GET  /medical_staff_registrations/new  → Form registrasi
POST /medical_staff_registrations      → Submit registrasi

# Approval (Hospital Manager only)
GET   /medical_staff_registrations     → List semua registrasi
PATCH /medical_staff_registrations/:id/approve → Approve
PATCH /medical_staff_registrations/:id/reject  → Reject
```

### Controller:
**File:** `app/controllers/medical_staff_registrations_controller.rb`

**Actions:**
- `new` - Form registrasi (public)
- `create` - Submit registrasi (public)
- `index` - List registrasi (manager only)
- `approve` - Approve registrasi (manager only)
- `reject` - Reject registrasi (manager only)

### Views:
1. **Form Registrasi:** `app/views/medical_staff_registrations/new.html.erb`
   - Informasi Akun (email, password)
   - Informasi Profesional (nama, license, spesialisasi, dll)

2. **Dashboard Manager:** `app/views/medical_staff_registrations/index.html.erb`
   - Pending registrations (dengan tombol approve/reject)
   - Approved registrations (20 terakhir)
   - Rejected registrations (10 terakhir)

---

## 🏥 Dashboard Hospital Manager

**File:** `app/views/dashboard/hospital_manager_dashboard.html.erb`

### Fitur:
- ✅ **Alert** untuk pending registrations
- ✅ **Quick Actions:**
  - Review Pendaftaran
  - Kelola Tenaga Medis
  - Kelola Pasien
- ✅ **Statistik:**
  - Total Dokter
  - Total Perawat
  - Total Pasien
  - Total Sesi
- ✅ **Recent Staff** - Tenaga medis terbaru
- ✅ **Recent Sessions** - Sesi pemeriksaan terbaru
- ✅ **Hospitals** - Daftar rumah sakit

---

## 🔄 Perubahan pada Model

### 1. RecordingSession Model
**File:** `app/models/recording_session.rb`

**Perubahan:**
```ruby
# Callback baru
before_create :generate_session_id

# Validasi baru
validates :session_id, uniqueness: true, allow_nil: true

# Method baru
private
def generate_session_id
  self.session_id ||= "session_#{SecureRandom.hex(12)}"
end
```

### 2. QrCode Model
**File:** `app/models/qr_code.rb`

**Perubahan:**
```ruby
# Relasi baru
belongs_to :recording_session, optional: true

# Method qr_payload telah diupdate (lihat di atas)
```

### 3. MedicalStaff Model
**File:** `app/models/medical_staff.rb`

**Perubahan:**
```ruby
# Validasi baru
validates :approval_status, inclusion: { in: %w[pending approved rejected] }, 
          allow_nil: true

# Scopes baru
scope :pending, -> { where(approval_status: 'pending') }
scope :approved, -> { where(approval_status: 'approved') }
scope :rejected, -> { where(approval_status: 'rejected') }

# Methods baru
def approved?
  approval_status == 'approved'
end

def pending?
  approval_status == 'pending'
end

def rejected?
  approval_status == 'rejected'
end
```

---

## 🔐 Perubahan pada Controller

### DashboardController
**File:** `app/controllers/dashboard_controller.rb`

**Method:** `create_session`

**Perubahan:**
```ruby
def create_session
  @session = RecordingSession.new(session_params)
  @session.status = 'active'
  @session.started_at = Time.current  # ← Baru
  
  if @session.save
    patient = @session.patient
    
    # QR Code sekarang terhubung dengan recording_session
    @qr_code = QrCode.create!(
      code: SecureRandom.hex(16),
      recording_session: @session,  # ← Baru
      hospital_id: current_user.hospital_id || patient.user.hospital_id,
      healthcare_provider: current_user,
      patient: patient,  # ← Baru
      valid_from: Time.current,
      valid_until: 24.hours.from_now,
      max_duration_minutes: 60,
      is_used: false
    )
    
    redirect_to nurse_dashboard_path, notice: 'Sesi pemeriksaan berhasil dibuat'
  else
    redirect_to nurse_dashboard_path, 
                alert: 'Gagal membuat sesi: ' + @session.errors.full_messages.join(', ')
  end
end
```

**Perbedaan:**
- ✅ Set `started_at` saat sesi dibuat
- ✅ Link QR code ke recording_session
- ✅ Link QR code ke patient
- ✅ Set semua required fields untuk QR code

---

## 🌐 Landing Page Update

**File:** `app/views/pages/landing.html.erb`

**Perubahan:**
- ✅ Tambahkan tombol "Daftar Tenaga Medis" di navigation
- ✅ Tambahkan link di footer untuk registrasi dokter/perawat

---

## 📝 TODO / Future Improvements

### High Priority:
1. **Email Notifications**
   - Kirim email saat pendaftaran diterima/ditolak
   - Kirim email konfirmasi registrasi

2. **Validasi Dokumen**
   - Upload file SIP/STR
   - Verifikasi dokumen oleh admin

3. **Alasan Penolakan**
   - Field untuk mencatat alasan reject
   - Tampilkan di notifikasi

### Medium Priority:
4. **Medical Staff Profile**
   - Halaman profil lengkap
   - Edit informasi
   - View sertifikasi

5. **Audit Trail**
   - Log semua approval/rejection
   - History perubahan status

6. **Search & Filter**
   - Search medical staff by name/license
   - Filter by hospital/specialization

### Low Priority:
7. **Bulk Actions**
   - Approve multiple registrations at once
   - Export data to CSV

---

## 🧪 Testing

### Manual Testing Checklist:

#### QR Code:
- [ ] QR code dibuat dengan semua field yang diperlukan
- [ ] `patient_identifier` muncul di payload
- [ ] `session_id` muncul di payload
- [ ] `durasi` dalam detik (bukan menit)
- [ ] `timestamp` format ISO 8601

#### Registrasi Medical Staff:
- [ ] Form registrasi dapat diakses tanpa login
- [ ] Submit form membuat User dan MedicalStaff
- [ ] Status default = 'pending'
- [ ] Hospital manager dapat melihat pending registrations
- [ ] Approve berfungsi (status → 'approved')
- [ ] Reject berfungsi (status → 'rejected')

#### Dashboard:
- [ ] Hospital manager melihat alert jika ada pending
- [ ] Quick action links berfungsi
- [ ] Statistics ditampilkan dengan benar

---

## 🚀 Deployment Notes

### Database Migration:
```bash
# Development
bin/rails db:migrate

# Production
RAILS_ENV=production bin/rails db:migrate
```

### Data Existing:
**PENTING:** Medical staffs yang sudah ada akan memiliki `approval_status = 'pending'` (default). 

**Action Required:**
```ruby
# Di Rails console, set existing medical staffs ke 'approved':
MedicalStaff.where(approval_status: nil).update_all(
  approval_status: 'approved',
  approved_at: Time.current
)
```

### Environment Variables:
Tidak ada environment variable baru yang diperlukan.

---

## 📞 Support

Jika ada pertanyaan atau issue:
1. Check error logs: `log/development.log` atau `log/production.log`
2. Check database: `bin/rails db`
3. Rollback migration jika diperlukan: `bin/rails db:rollback STEP=3`

---

## ✅ Completion Status

**Semua fitur telah diimplementasikan dan siap untuk testing!**

- ✅ Database migrations (3 files)
- ✅ Model updates (3 models)
- ✅ Controller baru (MedicalStaffRegistrationsController)
- ✅ Views baru (2 views)
- ✅ Routes update
- ✅ QR Code payload update
- ✅ Dashboard updates
- ✅ Landing page updates

**Total Files Changed:** 15+ files
**Total Lines Added:** ~1000+ lines

---

**Generated:** November 22, 2025
**Version:** 1.0.0
