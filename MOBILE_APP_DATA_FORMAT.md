# Format Data dari Mobile App untuk Grafik EKG

## 📱 Ekspektasi Data dari Mobile App

### 1. Saat Mulai Recording

**Endpoint:** `POST /api/recordings/start`

**Request dari Mobile:**
```json
{
  "qr_code": "{\"session_id\":\"702664379c264e04\",\"patient_identifier\":\"f2wkYtlhVFGF\",\"code\":\"abc123xyz\"}",
  "session_id": "702664379c264e04",
  "device_id": "CG-12345",
  "device_name": "CardioGuardian #1",
  "sample_rate": 500.0
}
```

**Response ke Mobile:**
```json
{
  "success": true,
  "message": "Recording dimulai",
  "data": {
    "recording_id": 1,
    "session_id": "702664379c264e04",
    "patient": {
      "id": 5,
      "name": "John Doe",
      "patient_identifier": "f2wkYtlhVFGF"
    },
    "max_duration_seconds": 3600,
    "sample_rate": 500.0,
    "started_at": "2025-11-22T10:30:00.000Z"
  }
}
```

---

### 2. Kirim Data Batch (Setiap 10 Detik)

**Endpoint:** `POST /api/recordings/data`

**Timing:**
- Kirim setiap **10 detik**
- Setiap batch = **5,000 samples** (500Hz × 10s)

**Request Format:**
```json
{
  "recording_id": 1,
  "batch_data": {
    "batch_sequence": 0,
    "start_timestamp": "2025-11-22T10:30:00.000Z",
    "end_timestamp": "2025-11-22T10:30:10.000Z",
    "sample_rate": 500.0,
    "samples": [
      0.523, 0.515, 0.318, -0.120, 0.423, 0.525, 0.328, 0.530, 0.633, 0.535,
      0.538, 0.540, 0.543, -0.145, 0.548, 0.550, 0.553, 0.555, 0.558, 0.560,
      ... (5000 float values in microvolts)
    ]
  }
}
```

**Data Details:**

| Field | Type | Description | Example |
|-------|------|-------------|---------|
| `recording_id` | Integer | ID dari response start recording | `1` |
| `batch_sequence` | Integer | Urutan batch (mulai dari 0) | `0, 1, 2, 3...` |
| `start_timestamp` | ISO 8601 | Waktu sample pertama | `2025-11-22T10:30:00.000Z` |
| `end_timestamp` | ISO 8601 | Waktu sample terakhir | `2025-11-22T10:30:10.000Z` |
| `sample_rate` | Float | Sampling rate (Hz) | `500.0` |
| `samples` | Array[Integer] | Array nilai sensor | `[512, 515, ...]` |

**Sample Values:**
- **Type:** Float
- **Unit:** Microvolts (µV)
- **Range:** Typically -5000 to +5000 µV for ECG signals
- **Jumlah:** Exactly `sample_rate × duration` = 500 × 10 = **5,000 values**

**Response:**
```json
{
  "success": true,
  "message": "Batch data berhasil disimpan",
  "data": {
    "recording_id": 1,
    "batch_sequence": 0,
    "samples_received": 5000,
    "total_batches": 1,
    "total_samples": 5000
  }
}
```

---

### 3. Flow Complete Recording (1 Jam)

```
Time 00:00 → Start Recording
             └─ POST /api/recordings/start
             └─ Get recording_id: 1

Time 00:10 → Batch 0 (samples 0-4999)
             └─ POST /api/recordings/data
             └─ batch_sequence: 0

Time 00:20 → Batch 1 (samples 5000-9999)
             └─ POST /api/recordings/data
             └─ batch_sequence: 1

Time 00:30 → Batch 2 (samples 10000-14999)
             └─ POST /api/recordings/data
             └─ batch_sequence: 2

...

Time 59:50 → Batch 359 (samples 1,795,000-1,799,999)
             └─ POST /api/recordings/data
             └─ batch_sequence: 359

Time 60:00 → Stop Recording
             └─ POST /api/recordings/1/stop
             └─ Total: 360 batches, 1,800,000 samples
```

---

### 4. Stop Recording

**Endpoint:** `POST /api/recordings/:id/stop`

**Request:**
```json
{
  "recording_id": 1
}
```

**Response:**
```json
{
  "success": true,
  "message": "Recording selesai",
  "data": {
    "recording_id": 1,
    "session_id": "702664379c264e04",
    "status": "completed",
    "started_at": "2025-11-22T10:30:00.000Z",
    "ended_at": "2025-11-22T11:30:00.000Z",
    "duration_seconds": 3600,
    "total_samples": 1800000
  }
}
```

---

## 🩺 Grafik EKG untuk Dokter

### 1. Fetch Data untuk Grafik

**Endpoint:** `GET /api/recordings/:id/batches`

**Request dari Frontend:**
```
GET /api/recordings/1/batches?page=1&per_page=60
```

**Query Parameters:**

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `page` | Integer | 1 | Halaman ke berapa |
| `per_page` | Integer | 60 | Jumlah batch per halaman (max 600) |

**60 batches = 10 menit = 300,000 samples**

**Response:**
```json
{
  "success": true,
  "data": {
    "recording_id": 1,
    "page": 1,
    "per_page": 60,
    "total_batches": 360,
    "total_pages": 6,
    "total_samples": 1800000,
    "sample_rate": 500.0,
    "batches": [
      {
        "id": 1,
        "batch_sequence": 0,
        "start_timestamp": "2025-11-22T10:30:00.000Z",
        "end_timestamp": "2025-11-22T10:30:10.000Z",
        "sample_rate": 500.0,
        "sample_count": 5000,
        "duration_seconds": 10.0,
        "samples": [512, 515, 518, 520, ..., 530],
        "statistics": {
          "min": 450,
          "max": 600,
          "mean": 520.5,
          "median": 518.0,
          "sample_count": 5000
        }
      },
      {
        "id": 2,
        "batch_sequence": 1,
        "start_timestamp": "2025-11-22T10:30:10.000Z",
        "end_timestamp": "2025-11-22T10:30:20.000Z",
        "sample_rate": 500.0,
        "sample_count": 5000,
        "duration_seconds": 10.0,
        "samples": [530, 533, 535, 538, ..., 550],
        "statistics": {
          "min": 460,
          "max": 610,
          "mean": 525.3,
          "median": 523.0,
          "sample_count": 5000
        }
      }
      // ... 58 more batches
    ]
  }
}
```

---

### 2. Render Grafik EKG (Frontend)

**JavaScript Example:**

```javascript
// Fetch data
async function loadEKGData(recordingId, page = 1) {
  const response = await fetch(
    `/api/recordings/${recordingId}/batches?page=${page}&per_page=60`
  );
  const { data } = await response.json();
  
  // Combine all samples from batches
  const allSamples = [];
  const timestamps = [];
  
  data.batches.forEach(batch => {
    const startTime = new Date(batch.start_timestamp).getTime();
    const sampleInterval = 1000 / batch.sample_rate; // 2ms for 500Hz
    
    batch.samples.forEach((value, index) => {
      const timestamp = startTime + (index * sampleInterval);
      timestamps.push(timestamp);
      allSamples.push(value);
    });
  });
  
  return {
    timestamps,
    values: allSamples,
    sampleRate: data.sample_rate,
    totalBatches: data.total_batches,
    currentPage: page,
    totalPages: data.total_pages
  };
}

// Render dengan Chart.js
async function renderEKGChart(recordingId) {
  const ekgData = await loadEKGData(recordingId, 1);
  
  const ctx = document.getElementById('ekgChart').getContext('2d');
  const chart = new Chart(ctx, {
    type: 'line',
    data: {
      labels: ekgData.timestamps,
      datasets: [{
        label: 'EKG Signal',
        data: ekgData.values,
        borderColor: '#10b981',
        borderWidth: 1,
        pointRadius: 0, // No points for smooth line
        tension: 0 // Sharp angles for EKG
      }]
    },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      scales: {
        x: {
          type: 'time',
          time: {
            unit: 'second',
            displayFormats: {
              second: 'HH:mm:ss'
            }
          },
          title: {
            display: true,
            text: 'Time'
          }
        },
        y: {
          title: {
            display: true,
            text: 'Amplitude (ADC units)'
          }
        }
      },
      plugins: {
        zoom: {
          pan: {
            enabled: true,
            mode: 'x'
          },
          zoom: {
            wheel: {
              enabled: true
            },
            pinch: {
              enabled: true
            },
            mode: 'x'
          }
        }
      }
    }
  });
  
  return chart;
}
```

---

### 3. Pagination untuk Recording Panjang

```javascript
// Navigation controls
function setupNavigation(ekgData) {
  const prevBtn = document.getElementById('prevBtn');
  const nextBtn = document.getElementById('nextBtn');
  const pageInfo = document.getElementById('pageInfo');
  
  let currentPage = ekgData.currentPage;
  
  // Update UI
  pageInfo.textContent = `Page ${currentPage} of ${ekgData.totalPages}`;
  prevBtn.disabled = currentPage === 1;
  nextBtn.disabled = currentPage === ekgData.totalPages;
  
  // Previous page
  prevBtn.onclick = async () => {
    if (currentPage > 1) {
      currentPage--;
      const newData = await loadEKGData(recordingId, currentPage);
      updateChart(chart, newData);
    }
  };
  
  // Next page
  nextBtn.onclick = async () => {
    if (currentPage < ekgData.totalPages) {
      currentPage++;
      const newData = await loadEKGData(recordingId, currentPage);
      updateChart(chart, newData);
    }
  };
}
```

---

## 🎯 Marker & Interpretasi Dokter

### 1. Data Structure untuk Marker

Kita perlu tambah tabel baru untuk menyimpan marker/annotation dari dokter.

**Migration:**
```ruby
create_table :ekg_markers do |t|
  t.references :recording, null: false, foreign_key: true
  t.references :created_by, null: false, foreign_key: { to_table: :users }
  t.string :marker_type # 'normal', 'arrhythmia', 'artifact', 'annotation'
  t.integer :batch_sequence
  t.integer :sample_index_start
  t.integer :sample_index_end
  t.datetime :timestamp_start
  t.datetime :timestamp_end
  t.string :label # 'P wave', 'QRS complex', 'T wave', 'Abnormal rhythm'
  t.text :description
  t.string :severity # 'low', 'medium', 'high', 'critical'
  t.jsonb :metadata # Extra data
  
  t.timestamps
end
```

### 2. API Endpoint untuk Marker

**POST /api/recordings/:id/markers**

**Request (Dokter kasih marker):**
```json
{
  "recording_id": 1,
  "marker": {
    "marker_type": "arrhythmia",
    "batch_sequence": 5,
    "sample_index_start": 1200,
    "sample_index_end": 1450,
    "timestamp_start": "2025-11-22T10:30:52.400Z",
    "timestamp_end": "2025-11-22T10:30:52.900Z",
    "label": "Ventricular Tachycardia",
    "description": "Detected abnormal heart rhythm, rate >100 bpm",
    "severity": "high"
  }
}
```

**Response:**
```json
{
  "success": true,
  "message": "Marker berhasil ditambahkan",
  "data": {
    "marker_id": 1,
    "recording_id": 1,
    "marker_type": "arrhythmia",
    "label": "Ventricular Tachycardia",
    "severity": "high",
    "created_by": "Dr. Sarah Chen",
    "created_at": "2025-11-22T12:00:00.000Z"
  }
}
```

**GET /api/recordings/:id/markers**

**Response:**
```json
{
  "success": true,
  "data": {
    "recording_id": 1,
    "total_markers": 5,
    "markers": [
      {
        "id": 1,
        "marker_type": "arrhythmia",
        "batch_sequence": 5,
        "sample_index_start": 1200,
        "sample_index_end": 1450,
        "timestamp_start": "2025-11-22T10:30:52.400Z",
        "timestamp_end": "2025-11-22T10:30:52.900Z",
        "label": "Ventricular Tachycardia",
        "description": "Detected abnormal heart rhythm",
        "severity": "high",
        "created_by": {
          "id": 3,
          "name": "Dr. Sarah Chen",
          "specialization": "Cardiologist"
        },
        "created_at": "2025-11-22T12:00:00.000Z"
      },
      {
        "id": 2,
        "marker_type": "annotation",
        "batch_sequence": 12,
        "sample_index_start": 3500,
        "sample_index_end": 3700,
        "timestamp_start": "2025-11-22T10:32:07.000Z",
        "timestamp_end": "2025-11-22T10:32:07.400Z",
        "label": "Normal Sinus Rhythm",
        "description": "Regular rhythm, normal P-QRS-T complex",
        "severity": "low",
        "created_by": {
          "id": 3,
          "name": "Dr. Sarah Chen",
          "specialization": "Cardiologist"
        },
        "created_at": "2025-11-22T12:05:00.000Z"
      }
    ]
  }
}
```

---

### 3. Frontend - Display Markers pada Grafik

**JavaScript Example:**

```javascript
// Load markers
async function loadMarkers(recordingId) {
  const response = await fetch(`/api/recordings/${recordingId}/markers`);
  const { data } = await response.json();
  return data.markers;
}

// Add markers to chart
function addMarkersToChart(chart, markers, ekgData) {
  markers.forEach(marker => {
    const startIndex = calculateGlobalIndex(marker);
    const endIndex = startIndex + (marker.sample_index_end - marker.sample_index_start);
    
    // Add colored region
    const annotation = {
      type: 'box',
      xMin: ekgData.timestamps[startIndex],
      xMax: ekgData.timestamps[endIndex],
      yMin: Math.min(...ekgData.values.slice(startIndex, endIndex)) - 50,
      yMax: Math.max(...ekgData.values.slice(startIndex, endIndex)) + 50,
      backgroundColor: getMarkerColor(marker.severity, 0.2),
      borderColor: getMarkerColor(marker.severity, 1),
      borderWidth: 2,
      label: {
        display: true,
        content: marker.label,
        position: 'start'
      }
    };
    
    chart.options.plugins.annotation.annotations.push(annotation);
  });
  
  chart.update();
}

// Helper functions
function calculateGlobalIndex(marker) {
  return (marker.batch_sequence * 5000) + marker.sample_index_start;
}

function getMarkerColor(severity, alpha) {
  const colors = {
    'low': `rgba(34, 197, 94, ${alpha})`,      // green
    'medium': `rgba(251, 191, 36, ${alpha})`,  // yellow
    'high': `rgba(249, 115, 22, ${alpha})`,    // orange
    'critical': `rgba(239, 68, 68, ${alpha})`  // red
  };
  return colors[severity] || colors['low'];
}
```

---

### 4. UI untuk Dokter Kasih Marker

**HTML:**

```html
<div class="ekg-viewer">
  <!-- Chart -->
  <div class="chart-container">
    <canvas id="ekgChart"></canvas>
  </div>
  
  <!-- Controls -->
  <div class="controls">
    <button id="prevBtn">← Previous 10 min</button>
    <span id="pageInfo">Page 1 of 6</span>
    <button id="nextBtn">Next 10 min →</button>
  </div>
  
  <!-- Marker Tool -->
  <div class="marker-tool">
    <h3>Add Marker</h3>
    <form id="markerForm">
      <select name="marker_type">
        <option value="normal">Normal</option>
        <option value="arrhythmia">Arrhythmia</option>
        <option value="artifact">Artifact</option>
        <option value="annotation">Annotation</option>
      </select>
      
      <input type="text" name="label" placeholder="Label (e.g., P wave)" />
      
      <select name="severity">
        <option value="low">Low</option>
        <option value="medium">Medium</option>
        <option value="high">High</option>
        <option value="critical">Critical</option>
      </select>
      
      <textarea name="description" placeholder="Description..."></textarea>
      
      <button type="submit">Add Marker</button>
    </form>
  </div>
  
  <!-- Markers List -->
  <div class="markers-list">
    <h3>Markers</h3>
    <div id="markersList"></div>
  </div>
</div>
```

**JavaScript untuk Add Marker:**

```javascript
// Enable selection on chart
let selectionStart = null;
let selectionEnd = null;

chart.options.onClick = (event, activeElements) => {
  if (activeElements.length > 0) {
    const index = activeElements[0].index;
    
    if (selectionStart === null) {
      selectionStart = index;
      highlightSelection(chart, selectionStart, selectionStart);
    } else if (selectionEnd === null) {
      selectionEnd = index;
      highlightSelection(chart, selectionStart, selectionEnd);
      
      // Show marker form
      showMarkerForm(selectionStart, selectionEnd);
    }
  }
};

// Submit marker
document.getElementById('markerForm').onsubmit = async (e) => {
  e.preventDefault();
  
  const formData = new FormData(e.target);
  const batchSequence = Math.floor(selectionStart / 5000);
  const sampleIndexStart = selectionStart % 5000;
  const sampleIndexEnd = selectionEnd % 5000;
  
  const response = await fetch(`/api/recordings/${recordingId}/markers`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      recording_id: recordingId,
      marker: {
        marker_type: formData.get('marker_type'),
        batch_sequence: batchSequence,
        sample_index_start: sampleIndexStart,
        sample_index_end: sampleIndexEnd,
        timestamp_start: new Date(ekgData.timestamps[selectionStart]).toISOString(),
        timestamp_end: new Date(ekgData.timestamps[selectionEnd]).toISOString(),
        label: formData.get('label'),
        description: formData.get('description'),
        severity: formData.get('severity')
      }
    })
  });
  
  if (response.ok) {
    alert('Marker added successfully!');
    // Reload markers
    const markers = await loadMarkers(recordingId);
    addMarkersToChart(chart, markers, ekgData);
    
    // Reset selection
    selectionStart = null;
    selectionEnd = null;
  }
};
```

---

## 📊 Complete Example Data Flow

### Scenario: Recording 1 Jam dengan Marker

**Step 1: Mobile App Kirim Data**
```
10:30:00 → Batch 0 [samples 0-4999]
10:30:10 → Batch 1 [samples 5000-9999]
10:30:20 → Batch 2 [samples 10000-14999]
...
10:32:00 → Batch 12 [samples 60000-64999]
           ↑ Ada arrhythmia di sample 61200-61450
...
11:30:00 → Stop (360 batches total)
```

**Step 2: Dokter Buka Dashboard**
```
GET /api/recordings/1/batches?page=1&per_page=60
→ Load 10 menit pertama (batch 0-59)
→ Render grafik EKG
```

**Step 3: Dokter Kasih Marker**
```
Dokter zoom in ke menit ke-2
Dokter select region: samples 61200-61450
Dokter kasih label: "Ventricular Tachycardia"
Dokter set severity: "high"

POST /api/recordings/1/markers
→ Marker saved
→ Marker muncul di grafik (red highlight)
```

**Step 4: Export/Report**
```
GET /api/recordings/1/report
→ Include:
  - Patient info
  - Recording duration & stats
  - All markers & interpretations
  - Preview grafik dengan markers
  - Doctor's signature
```

---

## 🚀 Summary

**Format Data yang Diharapkan:**

✅ **Batch format** dengan 5,000 samples per 10 detik
✅ **Sample rate** 500Hz konsisten
✅ **Timestamp** ISO 8601 accurate
✅ **Sequential** batch_sequence (0, 1, 2, ...)
✅ **Integer values** dari ADC (0-4095)

**Hasil untuk Dokter:**

✅ Grafik EKG smooth & real-time
✅ Zoom in/out capability
✅ Pagination untuk recording panjang
✅ Add markers dengan warna severity
✅ Statistics per batch
✅ Export & reporting

Mau saya implementasikan endpoint markers-nya juga?
