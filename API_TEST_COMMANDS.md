# 🧪 Recording History API - Test Commands

Quick reference for testing the new recording history endpoint.

---

## 🔑 Authentication

### 1. Login as Patient 1 (Ahmad)
```bash
curl -X POST http://localhost:3000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "pasien1@email.com",
    "password": "patient123"
  }'
```

**Expected Response:**
```json
{
  "success": true,
  "message": "Login successful",
  "data": {
    "user": { "id": 8, "email": "pasien1@email.com", "role": "patient", ... },
    "token": "eyJhbGci..."
  }
}
```

**Save the token for next requests!**

---

## 📊 Fetch Recordings

### 2. Get Own Recordings (as Patient)
```bash
TOKEN="<YOUR_TOKEN_HERE>"

curl -X GET "http://localhost:3000/api/recordings" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json"
```

**Expected Response:**
```json
{
  "success": true,
  "recordings": [
    {
      "id": 1,
      "user_id": 6,
      "device_id": null,
      "start_time": "2025-11-21T20:05:41.045+07:00",
      "end_time": "2025-11-21T21:05:41.045+07:00",
      "duration": 3600,
      "data_points": 1800000,
      "location": "RSUP Dr. Cipto Mangunkusumo",
      "status": "completed",
      "reviewed_by_doctor": true,
      "doctor_id": 4,
      "doctor_name": "Dr. Andi Wijaya, Sp.JP",
      "reviewed_at": "2025-11-22T20:05:41.045+07:00",
      "has_notes": true,
      "doctor_notes": "Hasil rekaman ECG menunjukkan ritme sinus normal. Tidak ditemukan aritmia atau kelainan signifikan. Pasien dalam kondisi stabil.",
      "diagnosis": "Normal Sinus Rhythm",
      "created_at": "2025-11-23T20:05:41.048+07:00",
      "updated_at": "2025-11-23T20:05:51.540+07:00"
    }
  ],
  "meta": {
    "current_page": 1,
    "next_page": null,
    "prev_page": null,
    "total_pages": 1,
    "total_count": 1
  }
}
```

---

### 3. Filter by Status
```bash
# Get only completed recordings
curl -X GET "http://localhost:3000/api/recordings?status=completed" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json"

# Get only active recordings
curl -X GET "http://localhost:3000/api/recordings?status=recording" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json"
```

---

### 4. Pagination
```bash
# Page 1, 10 results per page
curl -X GET "http://localhost:3000/api/recordings?page=1&per_page=10" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json"

# Page 2
curl -X GET "http://localhost:3000/api/recordings?page=2&per_page=10" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json"
```

---

## 🏥 Doctor Access

### 5. Login as Doctor
```bash
curl -X POST http://localhost:3000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "dr.andi@hospital.com",
    "password": "doctor123"
  }'
```

### 6. Doctor Fetching Patient's Recordings
```bash
DOCTOR_TOKEN="<DOCTOR_TOKEN_HERE>"

# Fetch patient 8's recordings
curl -X GET "http://localhost:3000/api/recordings?user_id=8" \
  -H "Authorization: Bearer $DOCTOR_TOKEN" \
  -H "Content-Type: application/json"

# Fetch patient 9's recordings
curl -X GET "http://localhost:3000/api/recordings?user_id=9" \
  -H "Authorization: Bearer $DOCTOR_TOKEN" \
  -H "Content-Type: application/json"
```

---

## ❌ Error Cases

### 7. No Authentication (401)
```bash
curl -X GET "http://localhost:3000/api/recordings" \
  -H "Content-Type: application/json"
```

**Expected Response:**
```json
{
  "success": false,
  "error": "Unauthorized",
  "message": "Invalid or missing authentication token"
}
```

---

### 8. Patient Accessing Another Patient's Data (403)
```bash
# Patient 1 tries to access Patient 2's data
PATIENT1_TOKEN="<PATIENT1_TOKEN>"

curl -X GET "http://localhost:3000/api/recordings?user_id=9" \
  -H "Authorization: Bearer $PATIENT1_TOKEN" \
  -H "Content-Type: application/json"
```

**Expected Response:**
```json
{
  "success": false,
  "error": "Forbidden",
  "message": "You cannot access another user's recordings"
}
```

---

### 9. Invalid User ID (404)
```bash
curl -X GET "http://localhost:3000/api/recordings?user_id=99999" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json"
```

**Expected Response:**
```json
{
  "success": false,
  "error": "User not found",
  "message": "User with id '99999' does not exist"
}
```

---

## 🧑‍🤝‍🧑 Test Accounts

### Patients:
| Email                 | Password    | Name          | Status                  |
|-----------------------|-------------|---------------|-------------------------|
| pasien1@email.com     | patient123  | Ahmad         | Has reviewed recording  |
| pasien2@email.com     | patient123  | Dewi          | Active recording        |
| pasien3@email.com     | patient123  | Rudi          | Not reviewed yet        |

### Doctors:
| Email                 | Password    | Name                    | Hospital |
|-----------------------|-------------|-------------------------|----------|
| dr.andi@hospital.com  | doctor123   | Dr. Andi Wijaya, Sp.JP  | RSCM     |
| dr.siti@hospital.com  | doctor123   | Dr. Siti Nurhaliza      | Siloam   |

---

## 🔍 JSON Field Reference

### Recording Object Fields:

| Field                  | Type     | Description                                      |
|------------------------|----------|--------------------------------------------------|
| id                     | integer  | Recording ID                                     |
| user_id                | integer  | User ID (medical staff who created session)      |
| device_id              | string   | Device identifier (currently null)               |
| start_time             | datetime | When recording started                           |
| end_time               | datetime | When recording ended                             |
| duration               | integer  | Duration in seconds                              |
| data_points            | integer  | Total number of samples                          |
| location               | string   | Hospital name                                    |
| status                 | string   | `completed`, `recording`, `pending`, etc.        |
| **reviewed_by_doctor** | boolean  | ✅ Has doctor reviewed this? (MANDATORY)         |
| **doctor_id**          | integer  | User ID of reviewing doctor (MANDATORY, nullable)|
| **doctor_name**        | string   | Name of reviewing doctor (MANDATORY, nullable)   |
| **reviewed_at**        | datetime | When doctor reviewed (MANDATORY, nullable)       |
| **has_notes**          | boolean  | Does doctor have notes? (MANDATORY)              |
| **doctor_notes**       | text     | Doctor's notes/comments (MANDATORY, nullable)    |
| **diagnosis**          | string   | Medical diagnosis (MANDATORY, nullable)          |
| created_at             | datetime | Record creation time                             |
| updated_at             | datetime | Last update time                                 |

### Meta Object Fields:

| Field         | Type    | Description                    |
|---------------|---------|--------------------------------|
| current_page  | integer | Current page number            |
| next_page     | integer | Next page number (null if last)|
| prev_page     | integer | Previous page (null if first)  |
| total_pages   | integer | Total number of pages          |
| total_count   | integer | Total number of recordings     |

---

## 🎨 Mobile App UI Recommendations

### Recording List Item:
```
┌────────────────────────────────────────┐
│ 📊 Recording - Nov 21, 2025            │
│ Duration: 1 hour                       │
│ Location: RSUP Dr. Cipto Mangunkusumo │
│                                        │
│ ✅ Sudah Dilihat Dokter                │
│ 👨‍⚕️ Dr. Andi Wijaya, Sp.JP              │
│ 📝 Ada Catatan                         │
│                                        │
│ [Lihat Detail]                         │
└────────────────────────────────────────┘
```

### Recording Detail:
```
┌────────────────────────────────────────┐
│ Recording Details                      │
├────────────────────────────────────────┤
│ Started: Nov 21, 2025 20:05           │
│ Ended: Nov 21, 2025 21:05             │
│ Duration: 1 hour (3600 seconds)       │
│ Samples: 1,800,000 data points        │
│ Location: RSUP Dr. Cipto...           │
│ Status: Completed                     │
│                                        │
├────────────────────────────────────────┤
│ Doctor Review ✅                       │
├────────────────────────────────────────┤
│ Reviewed by:                           │
│ Dr. Andi Wijaya, Sp.JP                │
│                                        │
│ Diagnosis:                             │
│ Normal Sinus Rhythm                   │
│                                        │
│ Doctor's Notes:                        │
│ Hasil rekaman ECG menunjukkan ritme   │
│ sinus normal. Tidak ditemukan aritmia │
│ atau kelainan signifikan. Pasien      │
│ dalam kondisi stabil.                 │
│                                        │
│ Reviewed: Nov 22, 2025                │
└────────────────────────────────────────┘
```

### Recording Not Reviewed:
```
┌────────────────────────────────────────┐
│ 📊 Recording - Nov 18, 2025            │
│ Duration: 30 minutes                   │
│ Location: RSUP Dr. Cipto Mangunkusumo │
│                                        │
│ ⏳ Menunggu Review Dokter              │
│                                        │
│ [Lihat Data]                           │
└────────────────────────────────────────┘
```

---

## 🐛 Troubleshooting

### Issue: 401 Unauthorized
**Cause:** Missing or invalid JWT token  
**Solution:** 
1. Check if you included `Authorization: Bearer <token>` header
2. Verify token hasn't expired (tokens expire after ~10 days)
3. Re-login to get a fresh token

### Issue: 403 Forbidden
**Cause:** Patient trying to access another patient's data  
**Solution:** 
- Only access your own recordings (`user_id` = your user ID)
- Or login as a doctor to access any patient's data

### Issue: Empty recordings array
**Cause:** User has no recordings yet  
**Solution:** This is normal for new users. Create a recording first.

### Issue: 500 Internal Server Error
**Cause:** Server-side issue  
**Solution:** 
1. Check server logs
2. Verify database is running
3. Contact backend team

---

## 📚 Additional Resources

- **API Documentation:** `TUGAS_WEBAPP_IMPLEMENTATION_SUMMARY.md`
- **Task Requirements:** `TUGAS_TIM_WEBAPP_RECORDING_HISTORY_API.md`
- **Mobile API Guide:** `MOBILE_APP_API.md`

---

**Last Updated:** November 23, 2025  
**Version:** 1.0.0  
**Status:** ✅ Production Ready
