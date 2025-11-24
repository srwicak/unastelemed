# Fitur Drag-to-Select untuk Anotasi Range ✅

## ✨ Fitur Baru: Blok Area untuk Membuat Range

Sekarang Anda bisa membuat **marker range** dengan cara **drag (blok) area** langsung di grafik EKG!

### 🎯 Cara Menggunakan

#### 1. Aktifkan Mode Anotasi
- Klik tombol **"Mode Anotasi: OFF"**
- Tombol berubah menjadi **"🎯 Mode Anotasi: ON (Klik/Drag di grafik)"**
- Cursor berubah menjadi **crosshair** (tanda +)

#### 2. Membuat Marker Titik (Point)
**Cara:** Klik sekali di grafik
- Klik di titik waktu yang ingin ditandai
- Form akan terbuka otomatis dengan:
  - Tipe: **Point** (sudah terpilih)
  - Waktu: terisi otomatis sesuai titik klik
- Pilih label dan isi catatan
- Klik **Simpan Anotasi**

#### 3. Membuat Marker Range (Blok Area) ⭐ BARU!
**Cara:** Drag (klik tahan + geser) di grafik
1. **Klik dan tahan** di grafik pada waktu mulai
2. **Geser mouse** ke kanan/kiri (akan muncul kotak biru transparan)
3. **Lepas mouse** di waktu akhir
4. Form akan terbuka otomatis dengan:
   - Tipe: **Range** (sudah terpilih otomatis)
   - Waktu Mulai: terisi otomatis (waktu awal drag)
   - Waktu Akhir: terisi otomatis (waktu akhir drag)
5. Pilih label (misal: "Noise")
6. Isi catatan (opsional)
7. Klik **Simpan Anotasi**

### 🎨 Visual Feedback

#### Saat Drag (Blok Area)
- Muncul **kotak seleksi biru transparan** dengan border garis putus-putus
- Kotak mengikuti gerakan mouse
- Membuat visualisasi area yang akan ditandai

#### Setelah Disimpan
**Marker Range:**
- Ditampilkan sebagai **box biru transparan** dengan border solid
- Label muncul di tengah box dengan format: `"Label (Xs)"` (X = durasi dalam detik)
- Contoh: `"Noise (5s)"`

**Marker Titik:**
- Ditampilkan sebagai **garis vertikal merah** dengan garis putus-putus
- Label muncul di atas garis

### 🔧 Teknologi

#### Drag Selection System
```javascript
// State untuk tracking drag
let isDragging = false;
let dragStartX = null;
let dragStartTime = null;
let dragEndTime = null;
let selectionBox = null; // Visual selection box
```

#### Event Listeners
1. **mousedown** - Mulai drag, catat posisi awal
2. **mousemove** - Update selection box, track posisi akhir
3. **mouseup** - Selesai drag:
   - Jika jarak < 5px → **Point marker** (click)
   - Jika jarak ≥ 5px → **Range marker** (drag)

#### Auto-detect Tipe Marker
- Sistem otomatis mendeteksi apakah user melakukan **klik** atau **drag**
- Klik (jarak < 5px) → Form point marker
- Drag (jarak ≥ 5px) → Form range marker dengan start/end time sudah terisi

### 📊 Contoh Penggunaan

#### Menandai Noise
1. Mode Anotasi: ON
2. Drag dari detik 10.5 sampai detik 15.8
3. Muncul kotak biru selama drag
4. Lepas mouse → Form terbuka:
   - Waktu Mulai: `10.500`
   - Waktu Akhir: `15.800`
5. Pilih label: "Noise"
6. Catatan: "Gangguan gerakan pasien"
7. Simpan → Muncul box biru di grafik dengan label "Noise (5s)"

#### Menandai Aritmia (Titik)
1. Mode Anotasi: ON
2. Klik di detik 5.250
3. Form terbuka:
   - Waktu Mulai: `5.250`
4. Pilih label: "Aritmia"
5. Catatan: "QRS abnormal"
6. Simpan → Muncul garis merah vertikal di detik 5.250

### 🐛 Bug Fixes

#### ✅ Perbaikan JavaScript Error
**Masalah sebelumnya:**
- CSRF token tidak ditemukan
- Error handling kurang lengkap
- Validasi input kurang

**Solusi:**
```javascript
// Validasi lengkap sebelum save
if (!label) {
  alert('❌ Label harus diisi!');
  return;
}

if (isNaN(startTimeSeconds) || startTimeSeconds < 0) {
  alert('❌ Waktu mulai tidak valid!');
  return;
}

// Check CSRF token
const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content;
if (!csrfToken) {
  alert('❌ CSRF token tidak ditemukan!');
  return;
}

// Better error handling
try {
  result = await response.json();
} catch (parseError) {
  console.error('JSON parse error:', parseError);
  alert('❌ Server response tidak valid');
  return;
}
```

#### ✅ Console Logging untuk Debug
Semua operasi penting sekarang di-log:
```javascript
console.log('Saving annotation:', payload);
console.log('Server response:', response.status, result);
```

### 🎮 User Experience

#### Mode Anotasi ON
- ✅ Cursor: crosshair
- ✅ Pan/Zoom: disabled (untuk menghindari konflik)
- ✅ Click: membuat point marker
- ✅ Drag: membuat range marker
- ✅ Visual feedback: selection box saat drag

#### Mode Anotasi OFF
- ✅ Cursor: default
- ✅ Pan/Zoom: enabled
- ✅ Click/Drag: untuk navigasi grafik

### 📝 Tips Penggunaan

1. **Untuk marker range yang akurat:**
   - Gunakan zoom untuk memperbesar area yang ingin ditandai
   - Drag dengan smooth dari kiri ke kanan
   - Selection box akan menunjukkan area yang dipilih

2. **Untuk marker titik:**
   - Klik sekali dengan cepat
   - Jangan tahan mouse terlalu lama (akan jadi drag)

3. **Edit waktu manual:**
   - Jika hasil drag kurang pas, Anda bisa edit langsung di form
   - Ubah angka di field "Waktu Mulai" atau "Waktu Akhir"

4. **Cancel drag:**
   - Gerakkan mouse keluar dari area grafik
   - Atau tekan ESC (future feature)

### 🔒 Keamanan

- ✅ CSRF token validation
- ✅ Input validation (client-side & server-side)
- ✅ Permission check (hanya user dengan akses ke recording)

### 📈 Performance

- ✅ Drag system: lightweight, tidak lag
- ✅ Selection box: CSS transform (GPU accelerated)
- ✅ No performance impact pada chart rendering

### 🚀 Next Steps (Future Enhancement)

- [ ] Touch support untuk mobile/tablet
- [ ] Keyboard shortcut (ESC untuk cancel)
- [ ] Multi-select untuk batch annotation
- [ ] Template label (save frequently used labels)
- [ ] Undo/Redo untuk annotation

## 🎉 Summary

Fitur drag-to-select membuat pembuatan anotasi range jauh lebih intuitif dan cepat:
- **Sebelumnya:** Manual input waktu start/end
- **Sekarang:** Tinggal drag area yang ingin ditandai!

Visual feedback real-time membuat user tahu persis area mana yang akan ditandai sebelum menyimpan.
