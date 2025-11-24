# Fitur Anotasi Jantung - FIXED ✅

## Masalah yang Diperbaiki

### 1. ❌ Bug Penyimpanan Anotasi
**Masalah Sebelumnya:**
- Anotasi gagal disimpan karena JavaScript mengirim timestamp yang salah
- Konversi waktu dari detik ke timestamp tidak benar
- Tidak ada validasi di model

**Solusi:**
- ✅ Menambahkan parameter `start_time_seconds` dan `end_time_seconds` di controller
- ✅ Controller otomatis mengkonversi detik dari recording start ke timestamp yang benar
- ✅ Menambahkan validasi lengkap di model `Annotation`

### 2. ❌ Tidak Ada Fitur Marker Range
**Masalah Sebelumnya:**
- Hanya bisa membuat marker titik
- Tidak bisa menandai interval/range waktu tertentu

**Solusi:**
- ✅ Menambahkan pilihan tipe marker: **Titik (Point)** dan **Range (Interval)**
- ✅ Input waktu dalam format **detik** (lebih mudah dipahami)
- ✅ Untuk marker range, bisa input waktu mulai dan waktu akhir

## Fitur Baru

### 1. 📍 Marker Titik (Point Marker)
- Menandai **satu titik waktu** tertentu pada grafik EKG
- Ditampilkan sebagai **garis vertikal merah** dengan garis putus-putus
- Contoh penggunaan: menandai saat terjadi aritmia pada detik ke-5.250

### 2. 📏 Marker Range (Interval Marker)
- Menandai **interval waktu** dari detik A sampai detik B
- Ditampilkan sebagai **box biru transparan** dengan border biru
- Otomatis menghitung durasi (dalam detik)
- Contoh penggunaan: menandai noise dari detik 10.5 sampai 15.8

### 3. 🎨 Label Kategori Pre-defined
Pilihan label yang sudah disediakan:
- Aritmia
- Noise / Gangguan
- Artifact
- Normal
- Abnormal QRS
- ST Elevation
- ST Depression
- T Wave Abnormality
- Lainnya

### 4. 📝 Catatan Tambahan
- Field untuk menambahkan deskripsi detail
- Opsional, bisa dikosongkan

### 5. 📋 Daftar Anotasi
- Tombol "📋 Lihat Daftar Anotasi" untuk melihat semua anotasi
- Menampilkan detail setiap anotasi:
  - Tipe marker (Titik/Range)
  - Label dan waktu
  - Catatan (jika ada)
  - Pembuat anotasi
- Tombol hapus untuk setiap anotasi

### 6. 🎯 Mode Anotasi
Dua cara membuat anotasi:

**A. Mode Anotasi: ON**
- Klik tombol "Mode Anotasi: OFF" → berubah jadi "Mode Anotasi: ON"
- Kursor berubah jadi crosshair
- Klik di grafik untuk membuat anotasi di titik tersebut
- Form otomatis terisi dengan waktu yang diklik
- Pan/zoom dinonaktifkan saat mode anotasi aktif

**B. Manual**
- Klik tombol "+ Tambah Anotasi Manual"
- Isi waktu secara manual dalam detik
- Berguna jika sudah tahu waktu pastinya

## Cara Penggunaan

### Membuat Marker Titik
1. Klik tombol **"Mode Anotasi: OFF"** atau **"+ Tambah Anotasi Manual"**
2. Pilih **"Titik (Point)"**
3. Masukkan **Waktu Mulai** dalam detik (contoh: `5.250`)
4. Pilih **Label** (contoh: "Aritmia")
5. Tambahkan **Catatan** jika perlu
6. Klik **"Simpan Anotasi"**

### Membuat Marker Range
1. Klik tombol **"Mode Anotasi: OFF"** atau **"+ Tambah Anotasi Manual"**
2. Pilih **"Range (Interval)"**
3. Masukkan **Waktu Mulai** dalam detik (contoh: `10.5`)
4. Masukkan **Waktu Akhir** dalam detik (contoh: `15.8`)
5. Pilih **Label** (contoh: "Noise")
6. Tambahkan **Catatan** jika perlu
7. Klik **"Simpan Anotasi"**

### Melihat Daftar Anotasi
1. Klik tombol **"📋 Lihat Daftar Anotasi"**
2. Akan muncul modal dengan semua anotasi
3. Setiap anotasi menampilkan:
   - Tipe marker dengan warna berbeda
   - Waktu (mulai dan akhir untuk range)
   - Durasi (untuk range)
   - Label dan catatan
   - Nama pembuat

### Menghapus Anotasi
1. Buka **"📋 Lihat Daftar Anotasi"**
2. Klik tombol **"Hapus"** pada anotasi yang ingin dihapus
3. Konfirmasi penghapusan
4. Anotasi akan dihapus dari database dan grafik

## Visualisasi di Grafik

### Marker Titik
- **Warna:** Merah (#ff6384)
- **Bentuk:** Garis vertikal putus-putus
- **Label:** Ditampilkan di atas garis dengan background merah

### Marker Range
- **Warna:** Biru (#36a2eb)
- **Bentuk:** Box transparan dengan border biru
- **Label:** Ditampilkan di tengah box dengan durasi

## Validasi

Model `Annotation` sekarang memiliki validasi:
- ✅ `start_time` harus diisi
- ✅ `label` harus diisi (min 1 karakter, max 100 karakter)
- ✅ `notes` maksimal 500 karakter
- ✅ `end_time` harus setelah `start_time` (untuk range)

## API Endpoints

### GET `/recordings/:recording_id/annotations`
Mengambil semua anotasi untuk recording tertentu.

**Response:**
```json
[
  {
    "id": 1,
    "recording_id": 5,
    "start_time": "2025-11-24T10:15:30.250Z",
    "end_time": null,
    "label": "Aritmia",
    "notes": "QRS abnormal",
    "created_by": {
      "id": 2,
      "name": "Dr. John Doe"
    },
    "marker_type": "point",
    "duration_seconds": 0
  },
  {
    "id": 2,
    "recording_id": 5,
    "start_time": "2025-11-24T10:15:40.500Z",
    "end_time": "2025-11-24T10:15:45.800Z",
    "label": "Noise",
    "notes": "Gangguan gerakan pasien",
    "created_by": {
      "id": 2,
      "name": "Dr. John Doe"
    },
    "marker_type": "range",
    "duration_seconds": 5
  }
]
```

### POST `/recordings/:recording_id/annotations`
Membuat anotasi baru.

**Request Body:**
```json
{
  "annotation": {
    "start_time_seconds": 5.250,
    "end_time_seconds": 10.5,
    "label": "Aritmia",
    "notes": "Catatan opsional"
  }
}
```

**Catatan:**
- Gunakan `start_time_seconds` dan `end_time_seconds` (dalam detik dari awal recording)
- Server otomatis mengkonversi ke timestamp yang benar
- `end_time_seconds` opsional (untuk marker titik, biarkan kosong)

### DELETE `/recordings/:recording_id/annotations/:id`
Menghapus anotasi.

**Authorization:**
- Hanya pembuat anotasi atau medical staff yang bisa menghapus

## Database Schema

```ruby
create_table :annotations do |t|
  t.references :recording, null: false, foreign_key: true
  t.datetime :start_time
  t.datetime :end_time
  t.string :label
  t.text :notes
  t.references :created_by, null: false, foreign_key: { to_table: :users }
  t.timestamps
end
```

## Testing

Untuk menguji fitur:
1. Buka recording EKG yang sudah ada
2. Coba buat marker titik dengan klik di grafik
3. Coba buat marker range dengan input manual
4. Lihat daftar anotasi
5. Coba hapus anotasi

## Catatan Penting

⚠️ **Format Waktu:** 
- Input waktu menggunakan **detik** dari awal recording
- Contoh: `5.250` = 5 detik 250 milidetik dari start recording
- Server otomatis mengkonversi ke timestamp absolut

⚠️ **Permissions:**
- Semua user yang punya akses ke recording bisa membuat anotasi
- Hanya pembuat atau medical staff yang bisa menghapus anotasi

⚠️ **UI/UX:**
- Mode anotasi menonaktifkan pan/zoom untuk menghindari konflik
- Klik "Mode Anotasi: OFF" untuk kembali ke mode pan/zoom normal

## Changelog

### [2025-11-24] - FIXED
- ✅ Fixed bug penyimpanan anotasi (konversi waktu salah)
- ✅ Menambahkan validasi di model Annotation
- ✅ Implementasi marker titik dan range
- ✅ Input waktu dalam format detik (lebih intuitif)
- ✅ Label kategori pre-defined
- ✅ Daftar anotasi dengan opsi hapus
- ✅ Visualisasi berbeda untuk titik (merah) dan range (biru)
- ✅ Mode anotasi dengan klik di grafik
- ✅ Manual input untuk waktu spesifik
