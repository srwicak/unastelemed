require 'nanoid'

puts "🌱 Seeding database..."

# 1. Create Superuser
puts "\n👑 Creating Superuser..."
superuser = User.find_or_create_by!(email: 'admin@hospital.com') do |user|
  user.name = 'Super Admin'
  user.password = 'admin123'
  user.password_confirmation = 'admin123'
  user.role = 'superuser'
end
puts "✅ Superuser: #{superuser.email} / admin123"

# 2. Create Hospitals
puts "\n🏥 Creating Hospitals..."
rs_cipto = Hospital.find_or_create_by!(code: 'RSCM') do |hospital|
  hospital.name = 'RSUP Dr. Cipto Mangunkusumo'
  hospital.address = 'Jl. Diponegoro No. 71, Jakarta Pusat'
  hospital.phone = '021-31900001'
  hospital.email = 'info@rscm.co.id'
end
puts "✅ #{rs_cipto.name}"

rs_siloam = Hospital.find_or_create_by!(code: 'SILOAM') do |hospital|
  hospital.name = 'RS Siloam Hospitals TB Simatupang'
  hospital.address = 'Jl. TB Simatupang Kav. 6, Jakarta Selatan'
  hospital.phone = '021-29962900'
  hospital.email = 'info@siloamhospitals.com'
end
puts "✅ #{rs_siloam.name}"

# 3. Create Hospital Managers
puts "\n👔 Creating Hospital Managers..."
manager_cipto = User.find_or_create_by!(email: 'manager.cipto@hospital.com') do |user|
  user.name = 'Manager RSCM'
  user.password = 'manager123'
  user.password_confirmation = 'manager123'
  user.role = 'hospital_manager'
  user.hospital = rs_cipto
  user.phone = '081234567890'
end
puts "✅ Manager RSCM: #{manager_cipto.email} / manager123"

manager_siloam = User.find_or_create_by!(email: 'manager.siloam@hospital.com') do |user|
  user.name = 'Manager Siloam'
  user.password = 'manager123'
  user.password_confirmation = 'manager123'
  user.role = 'hospital_manager'
  user.hospital = rs_siloam
  user.phone = '081234567891'
end
puts "✅ Manager Siloam: #{manager_siloam.email} / manager123"

# 4. Create Doctors
puts "\n👨‍⚕️ Creating Doctors..."
doctor1_user = User.find_or_create_by!(email: 'dr.andi@hospital.com') do |user|
  user.name = 'Dr. Andi Wijaya, Sp.JP'
  user.password = 'doctor123'
  user.password_confirmation = 'doctor123'
  user.role = 'doctor'
  user.hospital = rs_cipto
  user.phone = '081234567892'
end

doctor1 = MedicalStaff.find_or_create_by!(user: doctor1_user) do |staff|
  staff.name = 'Dr. Andi Wijaya, Sp.JP'
  staff.role = 'doctor'
  staff.hospital = rs_cipto
  staff.license_number = 'SIP-001-2024'
  staff.specialization = 'Kardiologi'
  staff.phone = '081234567892'
  staff.approval_status = 'approved'
  staff.approved_by = superuser.id
  staff.approved_at = Time.current
end
puts "✅ #{doctor1.name}"

doctor2_user = User.find_or_create_by!(email: 'dr.siti@hospital.com') do |user|
  user.name = 'Dr. Siti Nurhaliza, Sp.JP'
  user.password = 'doctor123'
  user.password_confirmation = 'doctor123'
  user.role = 'doctor'
  user.hospital = rs_siloam
  user.phone = '081234567893'
end

doctor2 = MedicalStaff.find_or_create_by!(user: doctor2_user) do |staff|
  staff.name = 'Dr. Siti Nurhaliza, Sp.JP'
  staff.role = 'doctor'
  staff.hospital = rs_siloam
  staff.license_number = 'SIP-002-2024'
  staff.specialization = 'Kardiologi'
  staff.phone = '081234567893'
  staff.approval_status = 'approved'
  staff.approved_by = superuser.id
  staff.approved_at = Time.current
end
puts "✅ #{doctor2.name}"

# 5. Create Nurses
puts "\n👩‍⚕️ Creating Nurses..."
nurse1_user = User.find_or_create_by!(email: 'ns.rina@hospital.com') do |user|
  user.name = 'Ns. Rina Kusuma, S.Kep'
  user.password = 'nurse123'
  user.password_confirmation = 'nurse123'
  user.role = 'nurse'
  user.hospital = rs_cipto
  user.phone = '081234567894'
end

nurse1 = MedicalStaff.find_or_create_by!(user: nurse1_user) do |staff|
  staff.name = 'Ns. Rina Kusuma, S.Kep'
  staff.role = 'nurse'
  staff.hospital = rs_cipto
  staff.license_number = 'STR-003-2024'
  staff.specialization = 'Perawat Umum'
  staff.phone = '081234567894'
  staff.approval_status = 'approved'
  staff.approved_by = manager_cipto.id
  staff.approved_at = Time.current
end
puts "✅ #{nurse1.name}"

nurse2_user = User.find_or_create_by!(email: 'ns.budi@hospital.com') do |user|
  user.name = 'Ns. Budi Santoso, S.Kep'
  user.password = 'nurse123'
  user.password_confirmation = 'nurse123'
  user.role = 'nurse'
  user.hospital = rs_siloam
  user.phone = '081234567895'
end

nurse2 = MedicalStaff.find_or_create_by!(user: nurse2_user) do |staff|
  staff.name = 'Ns. Budi Santoso, S.Kep'
  staff.role = 'nurse'
  staff.hospital = rs_siloam
  staff.license_number = 'STR-004-2024'
  staff.specialization = 'Perawat Umum'
  staff.phone = '081234567895'
  staff.approval_status = 'approved'
  staff.approved_by = manager_siloam.id
  staff.approved_at = Time.current
end
puts "✅ #{nurse2.name}"

# 6. Create Patients
puts "\n🧑‍🤝‍🧑 Creating Patients..."
patient1_user = User.find_or_create_by!(email: 'pasien1@email.com') do |user|
  user.name = 'Ahmad Sudrajat'
  user.password = 'patient123'
  user.password_confirmation = 'patient123'
  user.role = 'patient'
end

patient1 = Patient.find_or_create_by!(user: patient1_user) do |patient|
  patient.name = 'Ahmad Sudrajat'
  patient.patient_identifier = Nanoid.generate(size: 12)
  patient.date_of_birth = Date.new(1985, 5, 15)
  patient.gender = 'male'
  patient.phone_number = '081234567896'
  patient.address = 'Jl. Sudirman No. 10, Jakarta'
  patient.emergency_contact = 'Siti (Istri) - 081234567897'
  patient.blood_type = 'O'
  patient.allergies = 'Tidak ada'
  patient.medical_conditions = 'Hipertensi'
end
puts "✅ #{patient1.name} (ID: #{patient1.patient_identifier})"

patient2_user = User.find_or_create_by!(email: 'pasien2@email.com') do |user|
  user.name = 'Dewi Lestari'
  user.password = 'patient123'
  user.password_confirmation = 'patient123'
  user.role = 'patient'
end

patient2 = Patient.find_or_create_by!(user: patient2_user) do |patient|
  patient.name = 'Dewi Lestari'
  patient.patient_identifier = Nanoid.generate(size: 12)
  patient.date_of_birth = Date.new(1990, 8, 20)
  patient.gender = 'female'
  patient.phone_number = '081234567898'
  patient.address = 'Jl. Gatot Subroto No. 25, Jakarta'
  patient.emergency_contact = 'Budi (Suami) - 081234567899'
  patient.blood_type = 'A'
  patient.allergies = 'Penisilin'
  patient.medical_conditions = 'Diabetes Tipe 2'
end
puts "✅ #{patient2.name} (ID: #{patient2.patient_identifier})"

patient3_user = User.find_or_create_by!(email: 'pasien3@email.com') do |user|
  user.name = 'Rudi Hartono'
  user.password = 'patient123'
  user.password_confirmation = 'patient123'
  user.role = 'patient'
end

patient3 = Patient.find_or_create_by!(user: patient3_user) do |patient|
  patient.name = 'Rudi Hartono'
  patient.patient_identifier = Nanoid.generate(size: 12)
  patient.date_of_birth = Date.new(1978, 12, 10)
  patient.gender = 'male'
  patient.phone_number = '081234567800'
  patient.address = 'Jl. Kuningan No. 5, Jakarta'
  patient.emergency_contact = 'Ani (Istri) - 081234567801'
  patient.blood_type = 'B'
  patient.allergies = 'Tidak ada'
end
puts "✅ #{patient3.name} (ID: #{patient3.patient_identifier})"

# 7. Create Sample Recording Sessions
puts "\n📊 Creating Sample Recording Sessions..."
session1 = RecordingSession.find_or_create_by!(
  patient: patient1,
  medical_staff: nurse1
) do |session|
  session.session_id = SecureRandom.hex(8)
  session.status = 'completed'
  session.started_at = 2.days.ago
  session.ended_at = 2.days.ago + 24.hours
  session.interpretation_completed = true
  session.doctor_notes = 'Terdeteksi aritmia ringan, perlu monitoring berkala'
  session.diagnosis = 'Aritmia Sinus'
  session.recommendations = 'Kontrol rutin 1 bulan lagi, hindari kafein berlebih'
end

qr1 = QrCode.find_or_create_by!(recording_session: session1) do |qr|
  qr.code = SecureRandom.hex(16)
  qr.hospital = rs_cipto
  qr.healthcare_provider = nurse1_user
  qr.patient = patient1
  qr.valid_from = 2.days.ago
  qr.valid_until = 1.day.ago
  qr.expires_at = 1.day.ago
  qr.max_duration_minutes = 60
  qr.is_used = true
end

# Create Recording for session1
recording1 = Recording.find_or_create_by!(session_id: session1.session_id) do |rec|
  rec.patient = patient1
  rec.hospital = rs_cipto
  rec.user = nurse1_user
  rec.status = 'completed'
  rec.start_time = 2.days.ago
  rec.end_time = 2.days.ago + 1.hour
  rec.duration_seconds = 3600
  rec.sample_rate = 500.0
  rec.total_samples = 0
  # Set doctor review fields (this recording has been reviewed)
  rec.reviewed_by_doctor = true
  rec.doctor_id = doctor1_user.id
  rec.reviewed_at = 1.day.ago
  rec.has_notes = true
  rec.doctor_notes = 'Hasil rekaman ECG menunjukkan ritme sinus normal. Tidak ditemukan aritmia atau kelainan signifikan. Pasien dalam kondisi stabil.'
  rec.diagnosis = 'Normal Sinus Rhythm'
end

# Helper function to generate realistic EKG waveform
def generate_ekg_sample(time_in_seconds, heart_rate_bpm)
  # Calculate heart period
  heart_period = 60.0 / heart_rate_bpm
  
  # Position in current heartbeat cycle (0 to 1)
  cycle_position = (time_in_seconds % heart_period) / heart_period
  
  # Time in current cycle (in seconds)
  t = cycle_position * heart_period
  
  value = 0.0
  
  # P wave (atrial depolarization): 0.08-0.12s, amplitude ~0.15mV
  if t < 0.1
    p_center = 0.05
    p_width = 0.03
    value += 0.15 * Math.exp(-((t - p_center)**2) / (2 * p_width**2))
  end
  
  # PR segment (flat): 0.1-0.16s
  # (no additional value)
  
  # QRS complex: 0.16-0.24s
  if t >= 0.16 && t < 0.24
    qrs_t = t - 0.16
    
    # Q wave (small downward): 0.16-0.18s, amplitude -0.1mV
    if qrs_t < 0.02
      value += -0.1 * (qrs_t / 0.02)
    # R wave (sharp upward): 0.18-0.20s, amplitude 1.5mV
    elsif qrs_t < 0.04
      r_progress = (qrs_t - 0.02) / 0.02
      value += 1.5 * Math.sin(r_progress * Math::PI)
    # S wave (downward): 0.20-0.24s, amplitude -0.3mV
    else
      s_progress = (qrs_t - 0.04) / 0.04
      value += -0.3 * Math.sin(s_progress * Math::PI)
    end
  end
  
  # ST segment (flat): 0.24-0.32s
  # (no additional value)
  
  # T wave (ventricular repolarization): 0.32-0.48s, amplitude ~0.3mV
  if t >= 0.32 && t < 0.48
    t_center = 0.40
    t_width = 0.06
    value += 0.3 * Math.exp(-((t - t_center)**2) / (2 * t_width**2))
  end
  
  # Add minimal noise
  noise = (rand - 0.5) * 0.02
  
  (value + noise).round(4)
end

# Create sample batch data for recording1 (simulating 1 hour of recording)
puts "  📊 Creating sample EKG batch data with realistic PQRST waveform..."
batch_count = 0
heart_rate = 75 # 75 BPM - normal heart rate
360.times do |i|
  batch_start = 2.days.ago + (i * 10).seconds
  batch_end = batch_start + 10.seconds
  
  # Generate realistic EKG waveform samples (4000 samples per batch = 10 seconds at 400 Hz)
  samples = []
  4000.times do |j|
    # Calculate absolute time in seconds from start of recording
    time_in_seconds = (i * 10) + (j / 400.0)
    
    # Generate realistic EKG sample
    value = generate_ekg_sample(time_in_seconds, heart_rate)
    samples << value
  end
  
  BiopotentialBatch.find_or_create_by!(
    recording_id: recording1.id,
    batch_sequence: i
  ) do |batch|
    batch.start_timestamp = batch_start
    batch.end_timestamp = batch_end
    batch.sample_rate = 400.0
    batch.sample_count = samples.size
    batch.data = { samples: samples }
  end
  
  batch_count += 1
  print "\r  Creating batches: #{batch_count}/360" if batch_count % 10 == 0
end

# Update total samples
recording1.update!(total_samples: batch_count * 4000)
puts "\n  ✅ Created #{batch_count} batches (#{recording1.total_samples} samples)"

puts "✅ Session untuk #{patient1.name} (Completed)"

session2 = RecordingSession.find_or_create_by!(
  patient: patient2,
  medical_staff: nurse2
) do |session|
  session.session_id = SecureRandom.hex(8)
  session.status = 'active'
  session.started_at = 1.hour.ago
end

qr2 = QrCode.find_or_create_by!(recording_session: session2) do |qr|
  qr.code = SecureRandom.hex(16)
  qr.hospital = rs_siloam
  qr.healthcare_provider = nurse2_user
  qr.patient = patient2
  qr.valid_from = 1.hour.ago
  qr.valid_until = 23.hours.from_now
  qr.expires_at = 23.hours.from_now
  qr.max_duration_minutes = 60
  qr.is_used = true
end

# Create Recording for session2 (active recording - just started)
recording2 = Recording.find_or_create_by!(session_id: session2.session_id) do |rec|
  rec.patient = patient2
  rec.hospital = rs_siloam
  rec.user = nurse2_user
  rec.status = 'recording'
  rec.start_time = 1.hour.ago
  rec.sample_rate = 500.0
  rec.total_samples = 0
  # Not reviewed yet (defaults)
  rec.reviewed_by_doctor = false
  rec.has_notes = false
end

# Create just a few batches for the active recording (first 5 minutes)
puts "  📊 Creating sample EKG batch data for active recording with realistic PQRST waveform..."
batch_count = 0
heart_rate = 82 # 82 BPM - slightly elevated (patient might be anxious)
30.times do |i|
  batch_start = 1.hour.ago + (i * 10).seconds
  batch_end = batch_start + 10.seconds
  
  samples = []
  4000.times do |j|
    # Calculate absolute time in seconds from start of recording
    time_in_seconds = (i * 10) + (j / 400.0)
    
    # Generate realistic EKG sample
    value = generate_ekg_sample(time_in_seconds, heart_rate)
    samples << value
  end
  
  BiopotentialBatch.find_or_create_by!(
    recording_id: recording2.id,
    batch_sequence: i
  ) do |batch|
    batch.start_timestamp = batch_start
    batch.end_timestamp = batch_end
    batch.sample_rate = 400.0
    batch.sample_count = samples.size
    batch.data = { samples: samples }
  end
  
  batch_count += 1
end

recording2.update!(total_samples: batch_count * 4000)
puts "  ✅ Created #{batch_count} batches (#{recording2.total_samples} samples)"

puts "✅ Session untuk #{patient2.name} (Active)"

session3 = RecordingSession.find_or_create_by!(
  patient: patient3,
  medical_staff: nurse1
) do |session|
  session.session_id = SecureRandom.hex(8)
  session.status = 'completed'
  session.started_at = 5.days.ago
  session.ended_at = 5.days.ago + 30.minutes
  session.interpretation_completed = false
end

qr3 = QrCode.find_or_create_by!(recording_session: session3) do |qr|
  qr.code = SecureRandom.hex(16)
  qr.hospital = rs_cipto
  qr.healthcare_provider = nurse1_user
  qr.patient = patient3
  qr.valid_from = 5.days.ago
  qr.valid_until = 4.days.ago
  qr.expires_at = 4.days.ago
  qr.max_duration_minutes = 30
  qr.is_used = true
end

# Create Recording for session3 (completed but not reviewed yet)
recording3 = Recording.find_or_create_by!(session_id: session3.session_id) do |rec|
  rec.patient = patient3
  rec.hospital = rs_cipto
  rec.user = nurse1_user
  rec.status = 'completed'
  rec.start_time = 5.days.ago
  rec.end_time = 5.days.ago + 30.minutes
  rec.duration_seconds = 1800
  rec.sample_rate = 500.0
  rec.total_samples = 0
  # Not reviewed yet
  rec.reviewed_by_doctor = false
  rec.has_notes = false
end

# Create sample batch data for recording3 (30 minutes = 180 batches)
puts "  📊 Creating sample EKG batch data for recording3..."
batch_count = 0
heart_rate = 68 # 68 BPM - normal resting heart rate
180.times do |i|
  batch_start = 5.days.ago + (i * 10).seconds
  batch_end = batch_start + 10.seconds
  
  samples = []
  4000.times do |j|
    time_in_seconds = (i * 10) + (j / 400.0)
    value = generate_ekg_sample(time_in_seconds, heart_rate)
    samples << value
  end
  
  BiopotentialBatch.find_or_create_by!(
    recording_id: recording3.id,
    batch_sequence: i
  ) do |batch|
    batch.start_timestamp = batch_start
    batch.end_timestamp = batch_end
    batch.sample_rate = 400.0
    batch.sample_count = samples.size
    batch.data = { samples: samples }
  end
  
  batch_count += 1
  print "\r  Creating batches: #{batch_count}/180" if batch_count % 10 == 0
end

recording3.update!(total_samples: batch_count * 4000)
puts "\n  ✅ Created #{batch_count} batches (#{recording3.total_samples} samples)"

puts "✅ Session untuk #{patient3.name} (Completed, not reviewed)"

# 8. Create Recording with INCOMPLETE data (simulate connection lost)
puts "\n📊 Creating Recording with Incomplete Data (simulating connection issue)..."
session4 = RecordingSession.find_or_create_by!(
  patient: patient1,
  medical_staff: nurse2
) do |session|
  session.session_id = SecureRandom.hex(8)
  session.status = 'completed'
  session.started_at = 3.days.ago
  session.ended_at = 3.days.ago + 5.minutes  # Short recording
  session.interpretation_completed = false
end

qr4 = QrCode.find_or_create_by!(recording_session: session4) do |qr|
  qr.code = SecureRandom.hex(16)
  qr.hospital = rs_cipto
  qr.healthcare_provider = nurse2_user
  qr.patient = patient1
  qr.valid_from = 3.days.ago
  qr.valid_until = 3.days.ago + 1.hour
  qr.expires_at = 3.days.ago + 1.hour
  qr.max_duration_minutes = 60
  qr.is_used = true
end

# Recording yang data nya tidak lengkap (koneksi putus di tengah)
recording4 = Recording.find_or_create_by!(session_id: session4.session_id) do |rec|
  rec.patient = patient1
  rec.hospital = rs_cipto
  rec.user = nurse2_user
  rec.status = 'completed'
  rec.start_time = 3.days.ago
  rec.end_time = 3.days.ago + 5.minutes
  rec.duration_seconds = 300  # 5 minutes total
  rec.sample_rate = 500.0
  rec.total_samples = 0
  rec.reviewed_by_doctor = false
  rec.has_notes = false
end

# Hanya buat beberapa batch awal (simulasi koneksi putus setelah 30 detik)
puts "  📊 Creating partial EKG data (connection lost after 30 seconds)..."
batch_count = 0
heart_rate = 78
3.times do |i|  # Hanya 3 batch = 30 detik dari target 5 menit
  batch_start = 3.days.ago + (i * 10).seconds
  batch_end = batch_start + 10.seconds
  
  samples = []
  5000.times do |j|
    time_in_seconds = (i * 10) + (j / 500.0)
    value = generate_ekg_sample(time_in_seconds, heart_rate)
    samples << value
  end
  
  BiopotentialBatch.find_or_create_by!(
    recording_id: recording4.id,
    batch_sequence: i
  ) do |batch|
    batch.start_timestamp = batch_start
    batch.end_timestamp = batch_end
    batch.sample_rate = 500.0
    batch.sample_count = samples.size
    batch.data = { samples: samples }
  end
  
  batch_count += 1
end

recording4.update!(total_samples: batch_count * 5000)
puts "  ⚠️  Created only #{batch_count} batches (#{recording4.total_samples} samples) - Missing data after 30s!"
puts "✅ Session untuk #{patient1.name} (Completed, INCOMPLETE DATA)"

puts "\n✨ Seeding completed!"
puts "\n" + "="*60
puts "📋 LOGIN CREDENTIALS"
puts "="*60
puts "\n🔑 SUPERUSER:"
puts "   Email: admin@hospital.com"
puts "   Pass:  admin123"
puts "\n🏥 HOSPITAL MANAGERS:"
puts "   RSCM:   manager.cipto@hospital.com / manager123"
puts "   Siloam: manager.siloam@hospital.com / manager123"
puts "\n👨‍⚕️ DOCTORS:"
puts "   RSCM:   dr.andi@hospital.com / doctor123"
puts "   Siloam: dr.siti@hospital.com / doctor123"
puts "\n👩‍⚕️ NURSES:"
puts "   RSCM:   ns.rina@hospital.com / nurse123"
puts "   Siloam: ns.budi@hospital.com / nurse123"
puts "\n🧑‍🤝‍🧑 PATIENTS:"
puts "   pasien1@email.com / patient123 (Ahmad - Hipertensi)"
puts "   pasien2@email.com / patient123 (Dewi - Diabetes)"
puts "   pasien3@email.com / patient123 (Rudi)"
puts "\n" + "="*60
puts "🌐 Login at: http://localhost:3000/login"
puts "="*60

