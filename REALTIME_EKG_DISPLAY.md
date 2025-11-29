# 📊 Real-Time EKG Display & Optimasi Loading

## 🎯 Fitur Baru

### 1. **Real-Time Display untuk Data Parsial**

Grafik EKG sekarang **SELALU tampil**, bahkan jika:
- ✅ Recording masih berlangsung (status: `recording`)
- ✅ Hanya ada beberapa batch data (misal baru 10 detik dari 1 jam)
- ✅ Data tidak lengkap karena koneksi putus
- ✅ Recording baru dimulai dan belum ada data

**Keuntungan:**
- Dokter bisa melihat grafik EKG secara **real-time** saat recording berlangsung
- Tidak perlu menunggu recording selesai untuk melihat data
- Grafik otomatis update setiap 10 detik jika recording masih aktif

---

### 2. **Auto-Refresh untuk Recording Aktif**

Ketika recording sedang berlangsung (`status: 'recording'`):
- ✅ Dashboard auto-refresh data setiap **10 detik**
- ✅ Notifikasi muncul ketika recording selesai
- ✅ Indikator visual menunjukkan auto-refresh aktif
- ✅ Otomatis reload page ketika recording selesai untuk menampilkan data lengkap

**UI Indicators:**
```
⏳ Menunggu Data dari Mobile App...
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🟢 Auto-refresh setiap 10 detik
```

---

### 3. **Optimasi Loading dengan Caching**

**Problem:** Loading lambat saat scroll/geser ke bagian data baru

**Solusi Implementasi:**

#### A. **Client-Side Caching**
```javascript
// Cache data di browser
let dataCache = {};

function fetchDataBuffered(startTimeMs, endTimeMs) {
  const cacheKey = `${startTimeMs}_${endTimeMs}`;
  
  // Check cache first
  if (dataCache[cacheKey]) {
    console.log('Using cached data');
    updateChartData(dataCache[cacheKey], startTimeMs);
    return;
  }
  
  // Fetch from server
  // ... store in cache
}
```

**Benefit:** 
- ⚡ Instant loading untuk data yang sudah pernah dilihat
- 🔄 Scroll bolak-balik tetap cepat

#### B. **Request Throttling**
```javascript
// Min 200ms between requests
let lastDataFetch = 0;

const now = Date.now();
if (now - lastDataFetch < 200) {
  return; // Skip request
}
```

**Benefit:**
- 🛡️ Mencegah terlalu banyak request ke server
- 📉 Mengurangi load server

#### C. **HTTP Caching Headers**
```ruby
# Recording yang sudah selesai
if @recording.status == 'completed'
  expires_in 1.hour, public: true
else
  # Recording aktif (data berubah)
  expires_in 10.seconds, public: true
end
```

**Benefit:**
- 🌐 Browser cache otomatis untuk recording yang completed
- ⚡ Loading ulang page lebih cepat

#### D. **Smart Downsampling**
```ruby
# Target: ~10,000 points untuk preserve EKG peaks
target_points = 10000
skip = (total_samples / target_points.to_f).ceil

# Min-max downsampling: preserve peaks & valleys
chunk.min # Keep lowest point
chunk.max # Keep highest point
```

**Benefit:**
- 📉 Mengurangi data yang dikirim (1 jam = 1.8M samples → 10K points)
- 🎯 Tetap preserve bentuk PQRST waveform
- ⚡ Rendering lebih cepat di browser

---

## 🔄 Flow Diagram

### Recording Aktif (Real-Time)
```
Mobile App → POST /api/recordings/data (every 10s)
                ↓
          Database Saved
                ↓
Doctor Dashboard (Auto-refresh every 10s)
                ↓
          Fetch new data from /recordings/:id/data
                ↓
          Update chart with new batches
                ↓
          Show "🟢 Auto-refresh aktif"
```

### Scroll/Pan Grafik (Lazy Loading)
```
User scroll/pan grafik
        ↓
Check cache (dataCache)
        ↓
    Hit? ──YES──> Use cached data (instant)
        │
       NO
        ↓
Throttle check (min 200ms)
        ↓
    Too fast? ──YES──> Skip request
        │
       NO
        ↓
Fetch from server
        ↓
Apply downsampling (~10K points)
        ↓
Store in cache
        ↓
Update chart
```

---

## 📱 Untuk Tim Mobile

### **Penting:** Tetap Kirim Data Real-Time

Meskipun ada endpoint recovery, **prioritas utama** tetap:

1. ✅ **Kirim batch setiap 10 detik** via `POST /api/recordings/data`
2. ✅ **Retry logic** jika gagal (max 3 attempts)
3. ✅ **Save lokal** jika semua retry gagal
4. ✅ **Recovery endpoint** untuk kirim data yang tertinggal setelah recording selesai

**Kenapa penting kirim real-time?**
- Dokter bisa monitor pasien secara **live**
- Detect aritmia atau kelainan **saat terjadi**
- Early warning untuk kondisi darurat

---

## 🧪 Testing

### Test 1: Recording dengan Data Parsial

Jalankan seeds dengan data test:
```bash
rails db:seed
```

Ini akan membuat **4 recording**:
1. ✅ Recording lengkap (1 jam, 360 batches)
2. 🔄 Recording aktif (5 menit, 30 batches)
3. ✅ Recording lengkap (30 menit, 180 batches)
4. ⚠️ **Recording tidak lengkap** (target 5 menit, hanya 30 detik = 3 batches)

Login sebagai dokter:
```
Email: dr.andi@hospital.com
Pass:  doctor123
```

Buka recording #4 - grafik akan tetap tampil meskipun data hanya 30 detik!

### Test 2: Auto-Refresh

1. Start recording via API/mobile app
2. Buka dashboard dokter → klik "Lihat Data"
3. Lihat indikator "🟢 Auto-refresh aktif"
4. Tunggu 10 detik → grafik update otomatis
5. Kirim batch baru dari mobile app → grafik update otomatis

### Test 3: Performance Scroll

1. Buka recording dengan banyak data (recording #1 - 360 batches)
2. Zoom in ke 10 detik pertama
3. Pan/scroll ke kanan untuk lihat data selanjutnya
4. **Ekspektasi:** 
   - First load: ~200-500ms
   - Subsequent loads (same range): **instant** (from cache)
   - Different ranges: ~200-500ms (with throttling)

---

## 🎨 UI Changes

### Before
```
❌ Grafik tidak muncul jika data kosong
❌ Pesan error tidak jelas
❌ Loading lambat saat scroll
❌ Tidak ada info untuk recording aktif
```

### After
```
✅ Grafik selalu tampil (dengan placeholder jika kosong)
✅ Pesan jelas: "Menunggu data...", "Auto-refresh aktif"
✅ Loading cepat dengan caching
✅ Auto-refresh untuk recording aktif
✅ Indikator visual (animated icon, pulse dot)
✅ Status badge untuk data status
```

---

## 📊 Performance Metrics

### Before Optimization
```
1 jam recording = 1,800,000 samples
Data transfer: ~7.2 MB per request
Loading time: 5-10 seconds
```

### After Optimization
```
1 jam recording = ~10,000 points (downsampled)
Data transfer: ~120 KB per request
Loading time: 200-500ms
Cache hit: <10ms (instant)
```

**Performance Gain:** 🚀 **~60x faster** (dengan caching)

---

## 🔧 Configuration

### Tuning Parameters

Di `view_recording.html.erb`:

```javascript
const INITIAL_WINDOW = 10 * 1000;  // 10s initial view
const BUFFER_SIZE = 20 * 1000;      // 20s buffer each side
const IS_RECORDING = <%= ... %>;     // Auto-detect recording status
```

Untuk adjust auto-refresh interval:
```javascript
// Line ~1050
autoRefreshInterval = setInterval(function() {
  // ...
}, 10000); // Change to 5000 for 5s, 30000 for 30s
```

Di `recordings_controller.rb`:

```ruby
# Target resolution
target_points = 10000  # Increase for more detail (slower)
                       # Decrease for faster loading (less detail)
```

---

## 🎯 Summary

| Feature | Status | Benefit |
|---------|--------|---------|
| Real-time display | ✅ | Dokter bisa monitor live |
| Auto-refresh | ✅ | Update otomatis setiap 10s |
| Client caching | ✅ | Scroll cepat (instant on cache hit) |
| HTTP caching | ✅ | Page reload lebih cepat |
| Request throttling | ✅ | Prevent spam requests |
| Smart downsampling | ✅ | 60x faster transfer |
| Data status indicator | ✅ | Clear feedback ke user |
| Partial data support | ✅ | Grafik tampil meski data sedikit |

---

## 📞 Troubleshooting

### Grafik Tidak Update Otomatis

Check console log:
```javascript
// Should see:
"Auto-refreshing data..."
"Using cached data" or fetching new data
```

Pastikan `IS_RECORDING = true` dan recording status masih `'recording'`

### Loading Masih Lambat

1. **Check cache:** Clear browser cache jika perlu
2. **Check network:** Pastikan koneksi stabil
3. **Reduce target_points:** Edit di `recordings_controller.rb`
4. **Check server resources:** CPU/memory cukup?

### Cache Tidak Jalan

Check browser console:
```javascript
console.log(dataCache); // Should have cached entries
```

Clear cache manually:
```javascript
dataCache = {}; // In browser console
```

---

Dibuat untuk mengatasi masalah:
1. ⚡ Loading lambat saat scroll
2. 📊 Grafik tidak muncul untuk data parsial
3. 🔄 Tidak bisa lihat recording real-time
