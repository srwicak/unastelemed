# TUGAS TIM WEBAPP - Recording History API dengan Review Dokter

**Deadline:** URGENT  
**Priority:** HIGH  
**Assigned to:** Tim Backend Rails / Tim Webapp

---

## 🎯 TUJUAN

Mobile app membutuhkan endpoint untuk menampilkan **history recording pasien** beserta **status review dokter** dan **catatan medis**.

Pasien TIDAK perlu lihat grafik atau raw data, tapi perlu tahu:
- ✅ Recording sudah dilihat dokter atau belum
- ✅ Ada catatan/diagnosa dari dokter atau tidak
- ✅ Detail basic: waktu, durasi, status

---

## 📋 ENDPOINT YANG HARUS DIBUAT/UPDATE

### **1. GET /api/recordings**

**Purpose:** Ambil daftar recording milik pasien dengan info review dokter

**Query Parameters:**
```
user_id: string (required) - ID user/pasien
status: string (optional) - Filter by status: 'completed', 'active', 'failed'
page: integer (optional) - Default: 1
per_page: integer (optional) - Default: 20
```

**Headers:**
```http
Authorization: Bearer <jwt_token>
Content-Type: application/json
```

**Response Success (200):**
```json
{
  "success": true,
  "recordings": [
    {
      "id": "rec_uuid_12345",
      "user_id": "user_uuid_123",
      "device_id": "ESP32-001",
      "start_time": "2024-01-15T08:35:00Z",
      "end_time": "2024-01-15T09:30:00Z",
      "duration": 3300,
      "data_points": 19800,
      "location": "Rumah Sakit ABC - Ruang 201",
      "status": "completed",
      
      // ===== FIELD BARU YANG WAJIB ADA =====
      "reviewed_by_doctor": true,
      "doctor_id": "doc_uuid_456",
      "doctor_name": "Smith",
      "reviewed_at": "2024-01-15T10:00:00Z",
      "has_notes": true,
      "doctor_notes": "Hasil rekaman ECG menunjukkan ritme sinus normal. Tidak ditemukan aritmia atau kelainan signifikan. Pasien dalam kondisi stabil.",
      "diagnosis": "Normal Sinus Rhythm",
      // =====================================
      
      "created_at": "2024-01-15T08:30:00Z",
      "updated_at": "2024-01-15T10:00:00Z"
    },
    {
      "id": "rec_uuid_67890",
      "user_id": "user_uuid_123",
      "device_id": "ESP32-001",
      "start_time": "2024-01-14T14:00:00Z",
      "end_time": "2024-01-14T14:45:00Z",
      "duration": 2700,
      "data_points": 16200,
      "location": "Rumah Sakit ABC - Ruang 105",
      "status": "completed",
      
      // Contoh: Belum direview dokter
      "reviewed_by_doctor": false,
      "doctor_id": null,
      "doctor_name": null,
      "reviewed_at": null,
      "has_notes": false,
      "doctor_notes": null,
      "diagnosis": null,
      
      "created_at": "2024-01-14T13:55:00Z",
      "updated_at": "2024-01-14T14:45:00Z"
    }
  ],
  "meta": {
    "current_page": 1,
    "total_pages": 1,
    "total_count": 2,
    "per_page": 20
  }
}
```

**Response Error (401):**
```json
{
  "success": false,
  "error": "Unauthorized",
  "message": "Invalid or missing authentication token"
}
```

**Response Error (404):**
```json
{
  "success": false,
  "error": "User not found",
  "message": "User with id 'user_123' does not exist"
}
```

---

## 🗄️ DATABASE SCHEMA CHANGES

### **Table: recordings**

Tambahkan kolom baru:

```sql
ALTER TABLE recordings ADD COLUMN reviewed_by_doctor BOOLEAN DEFAULT FALSE;
ALTER TABLE recordings ADD COLUMN doctor_id UUID REFERENCES users(id);
ALTER TABLE recordings ADD COLUMN reviewed_at TIMESTAMP;
ALTER TABLE recordings ADD COLUMN has_notes BOOLEAN DEFAULT FALSE;
ALTER TABLE recordings ADD COLUMN doctor_notes TEXT;
ALTER TABLE recordings ADD COLUMN diagnosis VARCHAR(255);

-- Index untuk performa
CREATE INDEX idx_recordings_reviewed ON recordings(reviewed_by_doctor);
CREATE INDEX idx_recordings_doctor_id ON recordings(doctor_id);
CREATE INDEX idx_recordings_user_reviewed ON recordings(user_id, reviewed_by_doctor);
```

**Penjelasan Field:**
- `reviewed_by_doctor`: Boolean, TRUE jika sudah dilihat dokter
- `doctor_id`: UUID dokter yang me-review (foreign key ke users table)
- `reviewed_at`: Timestamp kapan dokter me-review
- `has_notes`: Boolean, TRUE jika dokter memberikan catatan
- `doctor_notes`: Text panjang untuk catatan detail dokter
- `diagnosis`: String singkat untuk diagnosa (contoh: "Normal Sinus Rhythm", "Atrial Fibrillation")

---

## 🔧 IMPLEMENTASI BACKEND (Rails)

### **Controller: RecordingsController**

```ruby
class Api::RecordingsController < ApplicationController
  before_action :authenticate_user!
  
  def index
    user_id = params[:user_id] || current_user.id
    
    # Validasi user berhak akses data ini
    if current_user.id != user_id && !current_user.doctor?
      render json: { 
        success: false, 
        error: 'Forbidden',
        message: 'You cannot access another user\'s recordings' 
      }, status: :forbidden
      return
    end
    
    recordings = Recording.where(user_id: user_id)
                          .order(created_at: :desc)
                          .page(params[:page])
                          .per(params[:per_page] || 20)
    
    # Filter by status jika ada
    recordings = recordings.where(status: params[:status]) if params[:status].present?
    
    render json: {
      success: true,
      recordings: recordings.map { |r| recording_json(r) },
      meta: {
        current_page: recordings.current_page,
        total_pages: recordings.total_pages,
        total_count: recordings.total_count,
        per_page: recordings.limit_value
      }
    }
  end
  
  private
  
  def recording_json(recording)
    {
      id: recording.id,
      user_id: recording.user_id,
      device_id: recording.device_id,
      start_time: recording.start_time,
      end_time: recording.end_time,
      duration: recording.duration,
      data_points: recording.data_points,
      location: recording.location,
      status: recording.status,
      
      # Info review dokter
      reviewed_by_doctor: recording.reviewed_by_doctor || false,
      doctor_id: recording.doctor_id,
      doctor_name: recording.doctor&.name, # Asumsi ada relasi belongs_to :doctor
      reviewed_at: recording.reviewed_at,
      has_notes: recording.has_notes || false,
      doctor_notes: recording.doctor_notes,
      diagnosis: recording.diagnosis,
      
      created_at: recording.created_at,
      updated_at: recording.updated_at
    }
  end
end
```

### **Model: Recording**

```ruby
class Recording < ApplicationRecord
  belongs_to :user
  belongs_to :doctor, class_name: 'User', optional: true
  
  # Validations
  validates :user_id, presence: true
  validates :start_time, presence: true
  validates :status, presence: true, inclusion: { in: %w[active completed failed] }
  
  # Callbacks
  before_save :update_has_notes_flag
  
  # Scopes
  scope :reviewed, -> { where(reviewed_by_doctor: true) }
  scope :not_reviewed, -> { where(reviewed_by_doctor: false) }
  scope :with_notes, -> { where(has_notes: true) }
  
  private
  
  def update_has_notes_flag
    self.has_notes = doctor_notes.present?
  end
end
```

---

## 🧪 TESTING

### **Test Cases yang Harus Dipastikan:**

1. ✅ GET /api/recordings tanpa auth → return 401
2. ✅ GET /api/recordings dengan valid token → return list recordings
3. ✅ GET /api/recordings?user_id=other_user (bukan dokter) → return 403
4. ✅ GET /api/recordings dengan recording yang belum direview → `reviewed_by_doctor: false`, semua field dokter `null`
5. ✅ GET /api/recordings dengan recording yang sudah direview → semua field review terisi
6. ✅ GET /api/recordings?status=completed → hanya return completed recordings
7. ✅ Pagination berfungsi dengan benar

### **Sample cURL untuk Testing:**

```bash
# Login dulu untuk dapat token
curl -X POST http://localhost:3000/api/login \
  -H "Content-Type: application/json" \
  -d '{"email": "patient@test.com", "password": "password123"}'

# Get recordings
curl -X GET "http://localhost:3000/api/recordings?user_id=user_uuid_123" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -H "Content-Type: application/json"

# Get recordings with filter
curl -X GET "http://localhost:3000/api/recordings?user_id=user_uuid_123&status=completed&page=1&per_page=10" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -H "Content-Type: application/json"
```

---

## 📱 MOBILE APP USAGE

Mobile app sudah siap menerima response dengan format di atas. 

**Tampilan yang akan dibuat:**
- Badge "✅ Sudah Dilihat Dokter" (hijau) atau "⏳ Menunggu Review Dokter" (orange)
- Badge "📝 Ada Catatan" (biru) jika `has_notes: true`
- Tombol "Lihat Catatan" untuk membuka dialog dengan `doctor_notes` dan `diagnosis`
- Info dokter dan waktu review

**Tidak perlu:**
- ❌ Grafik ECG di history screen
- ❌ Raw data atau CSV
- ❌ Average temperature (field ini bisa dihapus)

---

## 🚨 CATATAN PENTING

1. **Field `reviewed_by_doctor`, `has_notes`, `doctor_notes`, `diagnosis` WAJIB ada** di response, meskipun nilainya `null` atau `false`
2. **Jangan kirim data recording pasien lain** kecuali user adalah dokter
3. **Pagination wajib** untuk performa (bisa banyak recordings)
4. **Sort by `created_at DESC`** - recording terbaru di atas
5. **Filter by status** harus berfungsi untuk fitur filter nanti

---

## ✅ CHECKLIST TUGAS

- [ ] Tambah kolom di table `recordings` (migration)
- [ ] Update model `Recording` dengan relasi ke `User` (doctor)
- [ ] Implementasi `GET /api/recordings` di controller
- [ ] Tambah authentication check
- [ ] Tambah authorization check (user hanya bisa akses data sendiri)
- [ ] Implement pagination
- [ ] Implement filter by status
- [ ] Write tests untuk endpoint
- [ ] Test manual dengan cURL/Postman
- [ ] Deploy ke staging
- [ ] Koordinasi dengan mobile team untuk testing

---

## 💬 KOORDINASI

**Jika ada pertanyaan, hubungi:**
- Mobile Team Lead (untuk klarifikasi format response)
- Backend Team Lead (untuk diskusi schema database)

**Setelah selesai:**
- Beritahu mobile team bahwa endpoint sudah siap
- Berikan base URL endpoint (development/staging)
- Berikan contoh token JWT untuk testing

---

## 🔮 FITUR FUTURE (TIDAK PRIORITAS SEKARANG)

- Notifikasi push ketika dokter sudah review recording
- Filter berdasarkan range tanggal
- Export PDF report catatan dokter
- Statistik jumlah recording per bulan
- Integration dengan sistem SOAP notes rumah sakit

---

**Updated:** November 23, 2025  
**Status:** PENDING IMPLEMENTATION  
**Estimated Time:** 4-6 hours development + 2 hours testing
