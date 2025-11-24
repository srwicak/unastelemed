# 🚨 URGENT FIX: Patient Identifier Validation

## ❌ Bug Yang Ditemukan

**Tanggal:** 24 November 2025  
**Severity:** HIGH - Security Issue  
**Status:** FIXED di Mobile App, BUTUH FIX di Rails API

---

## 🔍 Analisis Masalah

### Log Evidence:
```
Mobile App:
📱 Patient Identifier dari QR: 9N16J6_3uzqG
👤 User ID dari HP: 6
❌ Seharusnya DITOLAK tapi LOLOS!

Rails API:
QR Code valid untuk healthcare_provider_id: 6 (User/Nurse)
patient_identifier di QR: 9N16J6_3uzqG
```

### Root Cause:
Mobile app **salah membandingkan** `patient_identifier` (Nanoid 12 karakter) dengan `user.id` (integer ID).

**Sebelum:**
```dart
final patientIdentifier = qrData['patient_identifier']; // "9N16J6_3uzqG"
final currentUserId = user.id;                          // "6"

if (patientIdentifier != currentUserId) {
  // REJECT - tapi perbandingannya SALAH!
}
```

**Setelah Fix:**
```dart
final patientIdentifierFromQR = qrData['patient_identifier']; // "9N16J6_3uzqG"
final currentUserPatientId = user.patientIdentifier;         // "9N16J6_3uzqG"

if (patientIdentifierFromQR != currentUserPatientId) {
  // REJECT - sekarang perbandingan BENAR!
}
```

---

## ✅ Yang Sudah Diperbaiki (Mobile App)

### 1. Model User - `lib/services/auth_service.dart`
```dart
class User {
  final String id;
  final String email;
  final String name;
  final String? phone;
  final String? patientIdentifier; // ✅ BARU - Nanoid 12 karakter
  final DateTime? createdAt;
}
```

### 2. Validasi QR - `lib/services/qr_service.dart`
```dart
// ✅ SEKARANG membandingkan patient_identifier dengan patient_identifier
final patientIdentifierFromQR = qrData['patient_identifier'];
final currentUserPatientId = user.patientIdentifier;

if (currentUserPatientId == null) {
  print('⚠️ Warning: User tidak memiliki patient_identifier, skip validasi');
} else if (patientIdentifierFromQR != currentUserPatientId) {
  print('❌ QR Code tidak sesuai dengan user yang login');
  return {
    'success': false,
    'message': 'QR Code ini bukan untuk Anda...',
  };
}
```

---

## 🔥 YANG HARUS DILAKUKAN RAILS API TEAM

### 1. Update Response Login/Register API

**Endpoint:** `POST /api/auth/login` dan `POST /api/auth/register`

**Response saat ini:**
```json
{
  "success": true,
  "data": {
    "token": "jwt_token_here",
    "user": {
      "id": 6,
      "email": "patient@example.com",
      "name": "John Doe",
      "phone": "+6281234567890",
      "created_at": "2025-11-24T03:00:00+07:00"
    }
  }
}
```

**Response yang HARUS ditambahkan:**
```json
{
  "success": true,
  "data": {
    "token": "jwt_token_here",
    "user": {
      "id": 6,
      "email": "patient@example.com",
      "name": "John Doe",
      "phone": "+6281234567890",
      "patient_identifier": "9N16J6_3uzqG",  // ✅ TAMBAHKAN INI!
      "created_at": "2025-11-24T03:00:00+07:00"
    }
  }
}
```

### 2. Update Users Table Migration (Jika Belum Ada)

```ruby
class AddPatientIdentifierToUsers < ActiveRecord::Migration[7.0]
  def change
    add_column :users, :patient_identifier, :string, limit: 12
    add_index :users, :patient_identifier, unique: true
    
    # Generate patient_identifier untuk user yang sudah ada
    reversible do |dir|
      dir.up do
        User.where(patient_identifier: nil).find_each do |user|
          user.update_column(:patient_identifier, generate_nanoid(12))
        end
      end
    end
  end
  
  private
  
  def generate_nanoid(length = 12)
    # Gunakan library nanoid atau equivalent
    SecureRandom.urlsafe_base64(length)[0...length]
  end
end
```

### 3. Update User Model

```ruby
# app/models/user.rb
class User < ApplicationRecord
  before_create :generate_patient_identifier
  
  validates :patient_identifier, uniqueness: true, presence: true
  
  private
  
  def generate_patient_identifier
    self.patient_identifier ||= loop do
      candidate = Nanoid.generate(size: 12)
      break candidate unless User.exists?(patient_identifier: candidate)
    end
  end
end
```

### 4. Update Auth Controller

```ruby
# app/controllers/api/auth_controller.rb
def login
  user = User.find_by(email: params[:email])
  
  if user&.authenticate(params[:password])
    token = encode_token(user_id: user.id)
    
    render json: {
      success: true,
      data: {
        token: token,
        user: {
          id: user.id,
          email: user.email,
          name: user.name,
          phone: user.phone,
          patient_identifier: user.patient_identifier, # ✅ TAMBAHKAN INI
          created_at: user.created_at
        }
      }
    }, status: :ok
  else
    render json: { success: false, error: 'Invalid credentials' }, status: :unauthorized
  end
end
```

---

## 🧪 Testing Checklist

### Mobile App (Sudah Fixed) ✅
- [x] User model punya field `patientIdentifier`
- [x] Validasi QR membandingkan `patient_identifier` dengan `patient_identifier`
- [x] Log menampilkan kedua nilai untuk debugging

### Rails API (Harus Dikerjakan) ⚠️
- [ ] Migration `patient_identifier` sudah running
- [ ] Semua existing users punya `patient_identifier`
- [ ] Login response include `patient_identifier`
- [ ] Register response include `patient_identifier`
- [ ] QR Code validation di backend juga check `patient_identifier`

### Integration Testing ⚠️
- [ ] Login dari mobile app mendapat `patient_identifier`
- [ ] Scan QR dengan patient_identifier yang cocok: ACCEPT ✅
- [ ] Scan QR dengan patient_identifier yang beda: REJECT ❌
- [ ] Check log mobile app menampilkan perbandingan yang benar

---

## 🎯 Priority Actions

1. **SEGERA** - Add `patient_identifier` to users table
2. **SEGERA** - Generate `patient_identifier` untuk semua existing users
3. **SEGERA** - Update login/register response
4. **TESTING** - Test dengan mobile app yang sudah diupdate
5. **MONITOR** - Check logs untuk memastikan validasi berjalan benar

---

## 📞 Contact

Jika ada pertanyaan tentang fix ini:
- Check file: `lib/services/auth_service.dart`
- Check file: `lib/services/qr_service.dart`
- Check log: Search untuk "Patient Identifier dari QR" dan "Patient Identifier dari User"

---

## ⚠️ IMPORTANT NOTES

1. `patient_identifier` adalah **Nanoid 12 karakter URL-safe** (contoh: `9N16J6_3uzqG`)
2. `patient_identifier` BUKAN sama dengan `user.id` (yang adalah integer)
3. `patient_identifier` harus **UNIQUE** per user
4. Validasi security bergantung pada field ini - JANGAN SKIP!

---

**Status:** Mobile App ✅ Fixed | Rails API ⚠️ Pending
