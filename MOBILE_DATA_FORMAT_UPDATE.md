# Update: Mobile Data Format - Float Microvolts

## 🔄 Perubahan Format Data

### ❌ Format Lama (Integer ADC)
```json
{
  "recording_id": 1,
  "batch_data": {
    "batch_sequence": 0,
    "start_timestamp": "2025-11-23T10:30:00.000Z",
    "end_timestamp": "2025-11-23T10:30:10.000Z",
    "sample_rate": 500.0,
    "samples": [512, 515, 518, 520, 523, ...]  // Integer ADC values (0-4095)
  }
}
```

### ✅ Format Baru (Float Microvolts)
```json
{
  "recording_id": 1,
  "batch_data": {
    "batch_sequence": 0,
    "start_timestamp": "2025-11-23T10:30:00.000Z",
    "end_timestamp": "2025-11-23T10:30:10.000Z",
    "sample_rate": 500.0,
    "samples": [0.523, 0.481, -0.123, 0.445, ...]  // Float microvolts (µV)
  }
}
```

## 📊 Spesifikasi Data

| Property | Type | Description | Example |
|----------|------|-------------|---------|
| **samples** | Array[Float] | Nilai biopotential dalam microvolts (µV) | `[0.523, -0.123, 0.445]` |
| **unit** | - | Microvolts (µV) | `µV` |
| **range** | Float | Typically -5000 to +5000 µV untuk ECG | `-5000..5000` |
| **count** | Integer | 5000 samples per batch (500Hz × 10 detik) | `5000` |

## 🎯 Keuntungan Format Baru

1. **✅ Nilai Real**: Langsung dalam microvolts, tidak perlu konversi
2. **✅ Negatif/Positif**: Support nilai negatif untuk signal deflection
3. **✅ Presisi Tinggi**: Float memberikan presisi yang lebih baik
4. **✅ Standard Medical**: Sesuai dengan standard medical device (µV)
5. **✅ No Conversion**: Frontend tidak perlu konversi ADC → µV

## 🔧 Implementasi Backend

Backend sudah support format baru:

- **Storage**: JSONB di PostgreSQL (support float)
- **Validation**: Tidak ada constraint tipe data
- **Processing**: Statistics calculation sudah support float
- **API**: Accept array of float values

## 📱 Contoh Request dari Android

```kotlin
// Data dalam microvolts (µV)
val microvoltSamples = floatArrayOf(0.523f, 0.481f, -0.123f, 0.445f, ...)

// Kirim sebagai float array
val payload = mapOf(
    "recording_id" to recordingId,
    "batch_data" to mapOf(
        "batch_sequence" to batchSequence,
        "start_timestamp" to startTime,
        "end_timestamp" to endTime,
        "sample_rate" to 500.0,
        "samples" to microvoltSamples.toList()  // Float array
    )
)

// POST ke server
api.sendBatchData(payload)
```

## 🩺 Display di Frontend

Frontend sekarang bisa langsung display nilai dalam µV:

```javascript
// Samples sudah dalam microvolts
const samples = batch.samples; // [0.523, 0.481, -0.123, ...]

// Display di chart
chart.data.datasets[0].data = samples.map((value, index) => ({
  x: batch.start_timestamp + (index * 2), // 2ms interval for 500Hz
  y: value // Already in µV, no conversion needed
}));

// Y-axis label
chart.options.scales.y.title.text = 'Amplitude (µV)';
```

## 🔍 Validasi

Backend akan validasi:

- ✅ samples harus Array
- ✅ samples.length = 5000 (untuk 500Hz × 10 detik)
- ✅ Setiap value harus numeric (int atau float)
- ✅ Tidak boleh null, NaN, atau string

## 🚨 Error Handling

Jika format salah:

```json
{
  "success": false,
  "error": "Validation error",
  "details": "samples array must contain numeric values"
}
```

## 📝 Migration Notes

**Tidak perlu migration database!** 

- JSONB sudah support float values
- Backend sudah compatible dengan format baru
- Old data (integer) tetap bisa dibaca
- New data (float) langsung bisa diterima

## ✅ Status

- ✅ Backend: Ready (JSONB support float)
- ✅ Documentation: Updated
- ✅ API Endpoints: Compatible
- ⏳ Frontend: Perlu update chart Y-axis label ke "µV"
- ⏳ Mobile App: Kirim float values instead of integer

---

**Last Updated**: November 23, 2025
