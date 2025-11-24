# 🎯 PANDUAN LENGKAP: Dari Daftar RS sampai Buat QR Code

## 📋 ALUR LENGKAP SISTEM

```
Superuser → Daftar RS + Manager → Manager Tambah Staff → Perawat Buat QR → Mobile Scan
```

---

## 🚀 LANGKAH-LANGKAH IMPLEMENTASI

### **STEP 1: Buat Superuser (Via Console)**

```bash
cd /home/srw/projects/cgwebapp/webapp
bin/rails console
```

```ruby
# Buat akun Superuser pertama kali
superuser = User.create!(
  name: "Admin Utama",
  email: "admin@system.com",
  password: "admin123",
  password_confirmation: "admin123",
  role: "superuser",
  phone: "+6281234567890"
)

puts "✅ Superuser created!"
puts "📧 Login: admin@system.com"
puts "🔑 Password: admin123"
```

---

### **STEP 2: Superuser Daftar Rumah Sakit**

#### **Via Web Interface:**

1. **Login sebagai Superuser**
   - URL: `/login`
   - Email: `admin@system.com`
   - Password: `admin123`

2. **Akses Dashboard Superuser**
   - Otomatis redirect ke `/superuser_dashboard`
   - Atau akses manual: `/superuser_dashboard`

3. **Klik "Daftarkan Rumah Sakit Baru"**
   - Atau akses langsung: `/hospitals/new`

4. **Isi Form Registrasi:**

   **📋 Informasi Rumah Sakit:**
   - Nama: `RS Jantung Harapan`
   - Kode: `RSJ001` (harus unik)
   - Telepon: `+62211234567`
   - Email: `info@rsjantung.com`
   - Alamat: `Jl. Kesehatan No. 123, Jakarta`

   **👤 Informasi Hospital Manager:**
   - Nama: `Budi Santoso`
   - Email: `budi.manager@rsjantung.com`
   - Telepon: `+628123456789`
   - Password: `manager123`
   - Konfirmasi Password: `manager123`

5. **Klik "Daftarkan Rumah Sakit"**

6. **✅ Berhasil!** Rumah Sakit dan Manager telah terdaftar

---

### **STEP 3: Hospital Manager Login & Tambah Staff**

#### **3.1 Login sebagai Hospital Manager:**

1. **Logout** dari akun Superuser (jika masih login)
2. **Login** dengan kredensial Manager:
   - URL: `/login`
   - Email: `budi.manager@rsjantung.com`
   - Password: `manager123`

3. **Dashboard Manager:**
   - Otomatis redirect ke `/hospital_manager_dashboard`

#### **3.2 Tambah Dokter:**

1. **Klik "Tambah Dokter/Perawat"**
   - Card hijau di dashboard
   - Atau akses: `/hospitals/{hospital_id}/add_staff`

2. **Isi Form Dokter:**

   **🔐 Informasi Akun:**
   - Posisi: `Dokter` ⚕️
   - Email: `sarah.dokter@rsjantung.com`
   - Password: `dokter123`
   - Konfirmasi Password: `dokter123`
   - Telepon: `+628234567890`

   **📋 Informasi Profesional:**
   - Nama Lengkap: `Dr. Sarah Wijaya`
   - Nomor Izin Praktik: `SIP.123456789`
   - Spesialisasi: `Kardiologi`

3. **Klik "Simpan & Tambahkan Staff"**

4. **✅ Dokter berhasil ditambahkan!**

#### **3.3 Tambah Perawat:**

Ulangi langkah yang sama, tapi pilih:
- Posisi: `Perawat` 👩‍⚕️
- Email: `siti.perawat@rsjantung.com`
- Password: `perawat123`
- Nama: `Siti Nurhaliza`
- Nomor STR: `STR.987654321`
- Spesialisasi: `Umum`

---

### **STEP 4: Daftar Pasien**

#### **Via Web (Pasien Daftar Sendiri):**

1. **Buka Homepage**
   - URL: `/` atau `/register`

2. **Klik "Daftar Sekarang"**

3. **Isi Form Registrasi Pasien:**
   - Nama: `Ahmad Rizki`
   - Email: `ahmad.pasien@email.com`
   - Password: `pasien123`
   - Tanggal Lahir: `15/05/1985`
   - Gender: `Laki-laki`
   - Telepon: `+628456789012`
   - Alamat: `Jl. Mawar No. 45, Jakarta`
   - Kontak Darurat: `+628567890123`

4. **Submit** → Pasien terdaftar dengan `patient_identifier` otomatis!

---

### **STEP 5: Perawat Buat QR Code untuk Sesi**

#### **5.1 Login sebagai Perawat:**

1. **Logout** dari akun sebelumnya
2. **Login:**
   - Email: `siti.perawat@rsjantung.com`
   - Password: `perawat123`

#### **5.2 Buat Sesi & QR Code:**

1. **Di Nurse Dashboard** (`/nurse_dashboard`)

2. **Klik "Buat Sesi Baru"** (tombol hijau)
   - Atau klik "Buat Sesi" di tabel pasien

3. **Isi Form:**
   - **Pilih Pasien:** `Ahmad Rizki`
   - **Catatan:** (opsional) `Pemeriksaan rutin EKG 24 jam`

4. **Klik "Buat Sesi"**

5. **✅ QR Code Otomatis Dibuat!**

---

### **STEP 6: QR Code Details**

QR Code yang dibuat akan berisi payload lengkap:

```json
{
  "code": "a1b2c3d4e5f6...",
  "patient_identifier": "xYz123AbC456",
  "session_id": "session_abc123def456",
  "durasi": 3600,
  "timestamp": "2025-11-22T10:30:00Z",
  "hospital_id": 1,
  "healthcare_provider_id": 5,
  "healthcare_provider_type": "User",
  "valid_until": "2025-11-23T10:30:00Z",
  "max_duration_minutes": 60
}
```

#### **Field Penting:**
- ✅ `patient_identifier` - ID unik pasien
- ✅ `session_id` - ID sesi pemeriksaan
- ✅ `durasi` - Durasi dalam **detik** (3600 = 1 jam)
- ✅ `timestamp` - Waktu pembuatan QR (ISO 8601)

---

### **STEP 7: Aplikasi Mobile Scan QR**

#### **Validate QR Code (API):**

```bash
curl -X POST http://localhost:3000/api/qr_codes/validate_by_code \
  -H "Content-Type: application/json" \
  -d '{
    "code": "a1b2c3d4e5f6..."
  }'
```

#### **Response:**

```json
{
  "success": true,
  "message": "QR Code is valid",
  "data": {
    "valid": true,
    "qr_code": {
      "code": "a1b2c3d4e5f6...",
      "patient_identifier": "xYz123AbC456",
      "session_id": "session_abc123def456",
      "durasi": 3600,
      "timestamp": "2025-11-22T10:30:00Z",
      "hospital_id": 1,
      "valid_until": "2025-11-23T10:30:00Z",
      "max_duration_minutes": 60,
      "duration_in_seconds": 3600
    },
    "session_info": {
      "can_start": true,
      "duration_minutes": 60
    },
    "healthcare_provider": {
      "id": 5,
      "name": "Siti Nurhaliza",
      "email": "siti.perawat@rsjantung.com",
      "role": "nurse"
    }
  }
}
```

---

## 📍 LOKASI FITUR DI APLIKASI

| Fitur | URL | Akses |
|-------|-----|-------|
| **Login** | `/login` | Semua |
| **Superuser Dashboard** | `/superuser_dashboard` | Superuser |
| **Daftar RS Baru** | `/hospitals/new` | Superuser |
| **List RS** | `/hospitals` | Superuser & Manager |
| **Manager Dashboard** | `/hospital_manager_dashboard` | Manager |
| **Tambah Dokter/Perawat** | `/hospitals/:id/add_staff` | Manager |
| **Nurse Dashboard** | `/nurse_dashboard` | Nurse |
| **Buat QR Code** | Form di Nurse Dashboard | Nurse |
| **Register Pasien** | `/register` | Public |

---

## 🔐 DEFAULT CREDENTIALS

### **Setelah Setup:**

```
Superuser:
  Email: admin@system.com
  Password: admin123

Hospital Manager (RS Jantung Harapan):
  Email: budi.manager@rsjantung.com
  Password: manager123

Dokter:
  Email: sarah.dokter@rsjantung.com
  Password: dokter123

Perawat:
  Email: siti.perawat@rsjantung.com
  Password: perawat123

Pasien:
  Email: ahmad.pasien@email.com
  Password: pasien123
```

---

## 🎨 FLOW DIAGRAM

```
┌─────────────┐
│ Superuser   │ Login → Daftar RS → Buat Manager
└──────┬──────┘
       │
       ▼
┌─────────────────┐
│ Hospital Manager│ Login → Tambah Dokter/Perawat
└────────┬────────┘
         │
         ▼
┌─────────────┐
│ Perawat     │ Login → Pilih Pasien → Buat Sesi → QR Code Generated!
└──────┬──────┘
       │
       ▼
┌─────────────┐
│ Aplikasi    │ Scan QR → Validate → Mulai Rekaman
│ Mobile      │
└─────────────┘
```

---

## ✅ CHECKLIST SETUP

- [x] Buat Superuser via console
- [x] Login sebagai Superuser
- [x] Daftarkan Rumah Sakit + Manager
- [x] Login sebagai Hospital Manager
- [x] Tambah Dokter (minimal 1)
- [x] Tambah Perawat (minimal 1)
- [x] Daftarkan Pasien (via web atau console)
- [x] Login sebagai Perawat
- [x] Buat Sesi untuk Pasien
- [x] QR Code otomatis terbuat!
- [x] Test validate QR via API

---

## 🎉 SELESAI!

Sistem sudah siap digunakan:
- ✅ Rumah Sakit terdaftar
- ✅ Manager dapat kelola staff
- ✅ Perawat dapat buat QR Code
- ✅ QR Code berisi semua field yang diperlukan
- ✅ Mobile app dapat validate & scan QR

---

## 🆘 TROUBLESHOOTING

### **QR Code tidak muncul:**
1. Cek apakah sesi berhasil dibuat
2. Cek database: `RecordingSession.last`
3. Cek QR code: `QrCode.last`

### **Patient identifier kosong:**
1. Cek apakah patient sudah ada
2. Run: `Patient.all.each { |p| p.update(patient_identifier: Nanoid.generate(size: 12)) if p.patient_identifier.nil? }`

### **Session ID tidak generate:**
1. Cek callback di RecordingSession model
2. Test: `rs = RecordingSession.create!(patient_id: 1, medical_staff_id: 1, status: 'active')`

---

**Last Updated:** November 22, 2025
**Version:** 2.0.0
