# Mobile App API Endpoints

## Base URL
```
http://localhost:3000/api
```

## Endpoints Overview

### 1. Validate QR Code
**POST** `/api/sessions/validate_qr`

Validates QR code scanned by mobile app.

**Request Body:**
```json
{
  "payload": "{\"session_id\":\"unique_session_identifier\",\"user_id\":\"user_id_from_system\",\"timestamp\":\"2024-01-15T10:30:00Z\",\"expiry\":\"2024-01-15T11:30:00Z\",\"device_type\":\"CardioGuardian\",\"validation_code\":\"secure_validation_hash\",\"code\":\"qr_code_here\",\"hospital_id\":1,\"healthcare_provider_id\":1,\"max_duration_minutes\":60}"
}
```

**Success Response (200):**
```json
{
  "success": true,
  "message": "QR code valid",
  "qr_code": {
    "id": 1,
    "code": "abc123...",
    "valid_until": "2024-01-15T11:30:00Z",
    "max_duration_minutes": 60,
    "max_duration_seconds": 3600
  },
  "session": {
    "session_id": "session_123",
    "status": "active",
    "started_at": "2024-01-15T10:30:00Z"
  },
  "patient": {
    "id": 1,
    "patient_identifier": "PAT001",
    "name": "John Doe",
    "date_of_birth": "1990-01-01",
    "gender": "male"
  },
  "hospital": {
    "id": 1,
    "name": "General Hospital",
    "code": "GH001"
  },
  "device_type": "CardioGuardian",
  "timestamp": "2024-01-15T10:30:00Z"
}
```

**Error Response (400/404/422):**
```json
{
  "success": false,
  "error": "Error message here"
}
```

---

### 2. Scan Device
**POST** `/api/devices/scan`

Validates CardioGuardian device connection.

**Request Body:**
```json
{
  "device_id": "CG-12345",
  "device_name": "CardioGuardian #1",
  "device_type": "CardioGuardian",
  "session_id": "session_123"
}
```

**Success Response (200):**
```json
{
  "success": true,
  "message": "Device berhasil terdeteksi dan tervalidasi",
  "device": {
    "device_id": "CG-12345",
    "device_name": "CardioGuardian #1",
    "device_type": "CardioGuardian",
    "connection_status": "connected",
    "firmware_version": "1.0.0",
    "battery_level": 100,
    "signal_quality": "good"
  },
  "session": {
    "session_id": "session_123",
    "status": "active",
    "patient_name": "John Doe"
  },
  "timestamp": "2024-01-15T10:30:00Z"
}
```

---

### 3. Start Recording
**POST** `/api/recordings/start`

Start a new recording session.

**Request Body:**
```json
{
  "qr_code": "{\"session_id\":\"session_123\",\"code\":\"abc123...\",\"hospital_id\":1,\"healthcare_provider_id\":1,\"max_duration_minutes\":60}",
  "session_id": "session_123",
  "device_id": "CG-12345",
  "device_name": "CardioGuardian #1",
  "sample_rate": 250.0
}
```

**Success Response (201):**
```json
{
  "success": true,
  "message": "Recording dimulai",
  "data": {
    "recording_id": 1,
    "session_id": "session_123",
    "patient": {
      "id": 1,
      "name": "John Doe",
      "patient_identifier": "PAT001"
    },
    "max_duration_seconds": 3600,
    "sample_rate": 250.0,
    "started_at": "2024-01-15T10:30:00Z"
  }
}
```

---

### 4. Send Sensor Data
**POST** `/api/recordings/data`

Send biopotential samples from device to server.

**⚡ NEW: Batch Format (RECOMMENDED for 500Hz data)**

This format is optimized for high-frequency data (up to 500Hz). Send data in batches every 10 seconds.

**Request Body (Batch Format):**
```json
{
  "recording_id": 1,
  "batch_data": {
    "batch_sequence": 0,
    "start_timestamp": "2024-01-15T10:30:00.000Z",
    "end_timestamp": "2024-01-15T10:30:10.000Z",
    "sample_rate": 500.0,
    "samples": [0.523, 0.481, -0.123, 0.445, ...] // Array of 5000 float values in microvolts (µV)
  }
}
```

**Success Response (201):**
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

**Benefits of Batch Format:**
- ✅ 10-30x faster than individual samples
- ✅ Reduced network requests (1 request per 10 seconds instead of 10)
- ✅ Optimized for high-frequency data (up to 500Hz)
- ✅ Better storage efficiency (JSONB format)
- ✅ Faster chart rendering for doctors

---

**Legacy: Individual Sample Format (For backward compatibility)**

**Request Body (Individual Samples):**
```json
{
  "recording_id": 1,
  "samples": [
    {
      "timestamp": "2024-01-15T10:30:00.000Z",
      "value": 512,
      "sequence": 0
    },
    {
      "timestamp": "2024-01-15T10:30:00.004Z",
      "value": 515,
      "sequence": 1
    }
  ]
}
```

**Success Response (201):**
```json
{
  "success": true,
  "message": "Data berhasil disimpan",
  "data": {
    "recording_id": 1,
    "samples_received": 2,
    "samples_saved": 2,
    "total_samples": 2
  }
}
```

**Note:** The individual sample format is kept for backward compatibility but is NOT recommended for high-frequency data (500Hz). Use batch format instead.

---

### 5. Stop Recording
**POST** `/api/recordings/:id/stop`

Stop the recording session.

**URL Parameters:**
- `id`: Recording ID

**Request Body (Optional - for batch upload workaround):**
```json
{
  "recording_id": 1,
  "batches": [
    {
      "batch_sequence": 0,
      "start_timestamp": "2024-01-15T10:30:00.000Z",
      "end_timestamp": "2024-01-15T10:30:10.000Z",
      "sample_rate": 500.0,
      "samples": [0.523, 0.481, -0.123, ...]
    },
    {
      "batch_sequence": 1,
      "start_timestamp": "2024-01-15T10:30:10.000Z",
      "end_timestamp": "2024-01-15T10:30:20.000Z",
      "sample_rate": 500.0,
      "samples": [0.445, 0.523, 0.481, ...]
    }
  ]
}
```

**Success Response (200):**
```json
{
  "success": true,
  "message": "Recording selesai",
  "data": {
    "recording_id": 1,
    "session_id": "session_123",
    "status": "completed",
    "started_at": "2024-01-15T10:30:00Z",
    "ended_at": "2024-01-15T11:30:00Z",
    "duration_seconds": 3600,
    "total_samples": 900000,
    "total_batches": 360
  }
}
```

**📝 Note about batch data:**
- **RECOMMENDED:** Send batches during recording using `/api/recordings/data` endpoint every 10 seconds
- **WORKAROUND:** If mobile app cannot send data during recording, you can send all batches array in the stop request
- The workaround approach may cause timeout for very long recordings (>5 minutes)

---

## QR Code Payload Format

The QR code generated by Rails contains the following JSON structure:

```json
{
  "session_id": "702664379c264e04",
  "patient_identifier": "f2wkYtlhVFGF",
  "timestamp": "2025-11-22T02:13:51Z",
  "expiry": "2025-11-23T02:13:51Z",
  "device_type": "CardioGuardian",
  "validation_code": "60d338770c1c4cb677404b8063dd9234",
  "max_duration_seconds": 3600
}
```

### Field Descriptions:
- `session_id` - Unique session identifier
- `patient_identifier` - Patient Nanoid (12 chars, URL-safe)
- `timestamp` - QR code creation time (ISO 8601)
- `expiry` - QR code expiration time (ISO 8601)
- `device_type` - Always "CardioGuardian"
- `validation_code` - Secure validation hash (32 chars hex)
- `max_duration_seconds` - Maximum recording duration in seconds

---

## Error Handling

All endpoints return consistent error responses:

**Bad Request (400):**
```json
{
  "success": false,
  "error": "Error description"
}
```

**Not Found (404):**
```json
{
  "success": false,
  "error": "Resource not found"
}
```

**Unprocessable Entity (422):**
```json
{
  "success": false,
  "error": "Validation error",
  "details": "Additional error details"
}
```

**Internal Server Error (500):**
```json
{
  "success": false,
  "error": "Terjadi kesalahan pada server"
}
```

---

## Testing with cURL

### Validate QR Code
```bash
curl -X POST http://localhost:3000/api/sessions/validate_qr \
  -H "Content-Type: application/json" \
  -d '{"payload": "{\"code\":\"abc123\",\"hospital_id\":1}"}'
```

### Scan Device
```bash
curl -X POST http://localhost:3000/api/devices/scan \
  -H "Content-Type: application/json" \
  -d '{
    "device_id": "CG-12345",
    "device_name": "CardioGuardian #1",
    "session_id": "session_123"
  }'
```

### Start Recording
```bash
curl -X POST http://localhost:3000/api/recordings/start \
  -H "Content-Type: application/json" \
  -d '{
    "qr_code": "{\"code\":\"abc123\",\"hospital_id\":1}",
    "device_id": "CG-12345",
    "sample_rate": 250.0
  }'
```

### Send Data
```bash
curl -X POST http://localhost:3000/api/recordings/data \
  -H "Content-Type: application/json" \
  -d '{
    "recording_id": 1,
    "samples": [
      {"timestamp": "2024-01-15T10:30:00.000Z", "value": 512, "sequence": 0}
    ]
  }'
```

### Stop Recording
```bash
curl -X POST http://localhost:3000/api/recordings/1/stop \
  -H "Content-Type: application/json"
```

---

## Mobile App Workflow

1. **Login** → User logs in with email & password via `/api/auth/login`
2. **Dashboard** → Display user profile
3. **Scan QR Code** → Scan QR from nurse dashboard
4. **Validate QR** → Send payload to `/api/sessions/validate_qr`
5. **Scan Device** → Connect to CardioGuardian via Bluetooth
6. **Validate Device** → Send device info to `/api/devices/scan`
7. **Start Recording** → Begin recording with `/api/recordings/start`
8. **Send Data** → Stream sensor data to `/api/recordings/data`
9. **Stop Recording** → End session with `/api/recordings/:id/stop`

---

## Notes

- All timestamps should be in ISO 8601 format
- Authentication can be added using JWT tokens in the `Authorization` header
- Sample rate is typically 250 Hz (250 samples per second) or **500 Hz (500 samples per second)** for high-quality ECG
- **⚡ For high-frequency data (500Hz), use the BATCH FORMAT:**
  - Send data every **10 seconds** (5,000 samples per batch at 500Hz)
  - Use `/api/recordings/data` with `batch_data` parameter
  - 10-30x faster than individual samples
  - Better storage efficiency and chart rendering performance
- **Legacy individual sample format:**
  - Batch sensor data in reasonable chunks (e.g., 100-1000 samples per request)
  - Only use for low-frequency data or backward compatibility
- The QR code expires after the `valid_until` timestamp
- QR codes can only be used once (is_used flag)

---

## Performance Guidelines for Mobile App

### Recommended Data Transmission Strategy (500Hz):

```
Recording Duration: 1 hour
Sample Rate: 500 Hz
Total Samples: 1,800,000

Batch Strategy:
- Send every: 10 seconds
- Samples per batch: 5,000
- Total requests: 360 (instead of 1,800,000!)
- Request size: ~20-30 KB per batch
- Total data: ~7-10 MB per hour
```

### Request Format Example (500Hz, 10 seconds):

```json
POST /api/recordings/data
{
  "recording_id": 1,
  "batch_data": {
    "batch_sequence": 0,
    "start_timestamp": "2024-01-15T10:30:00.000Z",
    "end_timestamp": "2024-01-15T10:30:10.000Z",
    "sample_rate": 500.0,
    "samples": [0.523, 0.481, -0.123, 0.445, ...] // 5000 float values in microvolts (µV)
  }
}
```

### Benefits:
- ✅ Reduced network overhead (360 requests vs 1.8M)
- ✅ Faster server processing (bulk insert)
- ✅ Better battery life on mobile device
- ✅ Smoother chart rendering for doctors
- ✅ Efficient storage (PostgreSQL JSONB)
