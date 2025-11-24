# Quick Testing Guide - Fitur Anotasi dengan Drag-to-Select

## 🚀 Cara Test Fitur

### 1. Login
```
URL: http://localhost:3000/login
Email: ns.rina@hospital.com
Password: nurse123
```

### 2. Buka Recording
- Dari dashboard, klik salah satu recording yang sudah ada
- Atau akses langsung: `http://localhost:3000/recordings/[ID]`

### 3. Test Mode Anotasi

#### A. Test Point Marker (Klik)
1. Klik tombol **"Mode Anotasi: OFF"**
2. Tombol berubah jadi **"🎯 Mode Anotasi: ON (Klik/Drag di grafik)"**
3. **Klik sekali** di grafik EKG
4. Form muncul dengan waktu sudah terisi
5. Pilih label (misal: "Aritmia")
6. Klik **Simpan Anotasi**
7. ✅ Harus muncul garis merah vertikal di grafik

#### B. Test Range Marker (Drag) ⭐
1. Pastikan Mode Anotasi: ON
2. **Klik dan tahan** di grafik (misal detik 5)
3. **Geser mouse** ke kanan (misal sampai detik 10)
4. Lihat **kotak biru transparan** muncul saat drag
5. **Lepas mouse**
6. Form muncul dengan:
   - Tipe: Range (otomatis)
   - Waktu Mulai: ~5.xxx
   - Waktu Akhir: ~10.xxx
7. Pilih label (misal: "Noise")
8. Klik **Simpan Anotasi**
9. ✅ Harus muncul box biru di grafik dengan label "Noise (5s)"

#### C. Test Lihat Daftar Anotasi
1. Klik tombol **"📋 Lihat Daftar Anotasi"**
2. ✅ Harus muncul modal dengan list semua anotasi
3. Cek apakah anotasi point dan range tampil berbeda
4. Test hapus anotasi dengan klik tombol **Hapus**

### 4. Expected Results

#### Console Browser (F12)
```javascript
// Saat save anotasi
Saving annotation: {annotation: {start_time_seconds: 5.234, label: "Aritmia", notes: ""}}
Server response: 201 {id: 1, recording_id: 1, ...}
```

#### Alert Messages
- ✅ Success: "✓ Anotasi berhasil disimpan!"
- ❌ Error: "❌ [error message]"

#### Visual di Grafik
- **Point:** Garis merah vertikal putus-putus + label
- **Range:** Box biru transparan + label dengan durasi

### 5. Debug Jika Error

#### Jika CSRF Token Error
```javascript
// Check di browser console:
document.querySelector('meta[name="csrf-token"]')?.content
// Harus return string token
```

#### Jika Gagal Simpan
1. Buka Browser Console (F12)
2. Lihat tab Network → Filter: "annotations"
3. Klik request yang gagal
4. Check Response untuk error message

#### Jika Selection Box Tidak Muncul
1. Pastikan Mode Anotasi: ON
2. Drag di area grafik (bukan di luar)
3. Check console untuk JavaScript error

### 6. Test Login Alternatif

#### Doctor (bisa review recording)
```
Email: dr.andi@hospital.com
Password: doctor123
```

#### Patient (view only)
```
Email: pasien1@email.com
Password: patient123
```

## 🔍 Checklist Testing

- [ ] Mode anotasi ON/OFF berfungsi
- [ ] Cursor berubah jadi crosshair saat mode ON
- [ ] Klik → buat point marker
- [ ] Drag → muncul selection box biru
- [ ] Drag → form otomatis terisi start/end time
- [ ] Form validation bekerja (label wajib diisi)
- [ ] Save anotasi berhasil (alert success)
- [ ] Point marker muncul di grafik (garis merah)
- [ ] Range marker muncul di grafik (box biru)
- [ ] Daftar anotasi tampil dengan benar
- [ ] Hapus anotasi berfungsi
- [ ] Pan/zoom disabled saat mode anotasi ON
- [ ] Pan/zoom enabled saat mode anotasi OFF

## 🐛 Known Issues & Solutions

### Issue: "CSRF token tidak ditemukan"
**Solution:** 
- Refresh halaman
- Clear browser cache
- Check layout application.html.erb ada `<%= csrf_meta_tags %>`

### Issue: Selection box tidak smooth
**Solution:**
- Normal, tergantung performa browser
- Akan smooth di production dengan optimasi

### Issue: Drag terlalu sensitif
**Solution:**
- Threshold sudah diset 5px
- Klik harus cepat, jangan tahan terlalu lama

## 📊 Test Data

Database sudah di-seed dengan:
- 3 Recording (ID: 1, 2, 3)
- Recording 1: Completed, 1 jam, 360 batches
- Recording 2: Active, 5 menit, 30 batches
- Recording 3: Completed, 30 menit, 180 batches

Semua punya data EKG realistik dengan PQRST waveform!

## 🎯 Success Criteria

Fitur dianggap berhasil jika:
1. ✅ Bisa buat point marker dengan klik
2. ✅ Bisa buat range marker dengan drag
3. ✅ Visual feedback (selection box) muncul saat drag
4. ✅ Anotasi tersimpan ke database
5. ✅ Anotasi tampil di grafik dengan benar
6. ✅ Bisa lihat list dan hapus anotasi

## 🚀 Ready to Test!

Server sudah running di: http://localhost:3000

Happy testing! 🎉
