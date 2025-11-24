# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2025_11_23_204740) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "annotations", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "created_by_id", null: false
    t.datetime "end_time"
    t.string "label"
    t.text "notes"
    t.bigint "recording_id", null: false
    t.datetime "start_time"
    t.datetime "updated_at", null: false
    t.index ["created_by_id"], name: "index_annotations_on_created_by_id"
    t.index ["recording_id"], name: "index_annotations_on_recording_id"
  end

  create_table "biopotential_batches", force: :cascade do |t|
    t.integer "batch_sequence", null: false
    t.datetime "created_at", null: false
    t.jsonb "data", default: {}, null: false
    t.datetime "end_timestamp", null: false
    t.float "max_value"
    t.float "min_value"
    t.bigint "recording_id", null: false
    t.integer "sample_count", null: false
    t.decimal "sample_rate", precision: 10, scale: 2, null: false
    t.datetime "start_timestamp", null: false
    t.datetime "updated_at", null: false
    t.index ["data"], name: "index_batches_on_data", using: :gin
    t.index ["recording_id", "batch_sequence"], name: "index_batches_on_recording_and_sequence", unique: true
    t.index ["recording_id", "start_timestamp"], name: "index_batches_on_recording_and_time"
    t.index ["recording_id"], name: "index_biopotential_batches_on_recording_id"
  end

  create_table "biopotential_samples", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "recording_id", null: false
    t.integer "sample_value"
    t.bigint "sequence_number"
    t.datetime "timestamp"
    t.datetime "updated_at", null: false
    t.index ["recording_id"], name: "index_biopotential_samples_on_recording_id"
  end

  create_table "ekg_markers", force: :cascade do |t|
    t.integer "batch_sequence", null: false
    t.datetime "created_at", null: false
    t.bigint "created_by_id", null: false
    t.text "description"
    t.string "label"
    t.string "marker_type", null: false
    t.jsonb "metadata", default: {}
    t.bigint "recording_id", null: false
    t.integer "sample_index_end", null: false
    t.integer "sample_index_start", null: false
    t.string "severity", default: "low"
    t.datetime "timestamp_end", null: false
    t.datetime "timestamp_start", null: false
    t.datetime "updated_at", null: false
    t.index ["created_by_id"], name: "index_ekg_markers_on_created_by_id"
    t.index ["recording_id", "batch_sequence"], name: "index_ekg_markers_on_recording_and_batch"
    t.index ["recording_id", "marker_type"], name: "index_ekg_markers_on_recording_and_type"
    t.index ["recording_id"], name: "index_ekg_markers_on_recording_id"
    t.index ["severity"], name: "index_ekg_markers_on_severity"
  end

  create_table "hospital_affiliations", force: :cascade do |t|
    t.boolean "active"
    t.datetime "created_at", null: false
    t.datetime "ended_at"
    t.bigint "hospital_id", null: false
    t.bigint "medical_staff_id", null: false
    t.datetime "started_at"
    t.string "status"
    t.datetime "updated_at", null: false
    t.index ["hospital_id"], name: "index_hospital_affiliations_on_hospital_id"
    t.index ["medical_staff_id"], name: "index_hospital_affiliations_on_medical_staff_id"
  end

  create_table "hospitals", force: :cascade do |t|
    t.text "address"
    t.string "code"
    t.datetime "created_at", null: false
    t.string "email"
    t.string "name"
    t.string "phone"
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_hospitals_on_code", unique: true
  end

  create_table "medical_staffs", force: :cascade do |t|
    t.string "approval_status", default: "pending"
    t.datetime "approved_at"
    t.integer "approved_by"
    t.datetime "created_at", null: false
    t.bigint "hospital_id", null: false
    t.string "license_number"
    t.string "name"
    t.string "phone"
    t.string "role"
    t.string "specialization"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["approval_status"], name: "index_medical_staffs_on_approval_status"
    t.index ["hospital_id"], name: "index_medical_staffs_on_hospital_id"
    t.index ["user_id"], name: "index_medical_staffs_on_user_id"
  end

  create_table "patients", force: :cascade do |t|
    t.text "address"
    t.text "allergies"
    t.string "blood_type"
    t.datetime "created_at", null: false
    t.date "date_of_birth"
    t.string "emergency_contact"
    t.string "gender"
    t.text "medical_conditions"
    t.string "medical_record_number"
    t.string "name"
    t.string "patient_identifier"
    t.string "phone_number"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["patient_identifier"], name: "index_patients_on_patient_identifier", unique: true
    t.index ["user_id"], name: "index_patients_on_user_id"
  end

  create_table "qr_codes", force: :cascade do |t|
    t.string "code"
    t.datetime "created_at", null: false
    t.datetime "expires_at"
    t.bigint "healthcare_provider_id", null: false
    t.string "healthcare_provider_type", null: false
    t.bigint "hospital_id", null: false
    t.boolean "is_used"
    t.integer "max_duration_minutes"
    t.bigint "patient_id", null: false
    t.string "patient_type", null: false
    t.bigint "recording_session_id"
    t.datetime "updated_at", null: false
    t.datetime "used_at"
    t.datetime "valid_from"
    t.datetime "valid_until"
    t.index ["code"], name: "index_qr_codes_on_code", unique: true
    t.index ["healthcare_provider_type", "healthcare_provider_id"], name: "index_qr_codes_on_healthcare_provider"
    t.index ["hospital_id"], name: "index_qr_codes_on_hospital_id"
    t.index ["patient_type", "patient_id"], name: "index_qr_codes_on_patient"
    t.index ["recording_session_id"], name: "index_qr_codes_on_recording_session_id"
  end

  create_table "recording_sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "diagnosis"
    t.text "doctor_notes"
    t.datetime "ended_at"
    t.boolean "interpretation_completed", default: false, null: false
    t.bigint "medical_staff_id", null: false
    t.text "notes"
    t.bigint "patient_id", null: false
    t.text "recommendations"
    t.string "session_id"
    t.datetime "started_at"
    t.string "status"
    t.datetime "updated_at", null: false
    t.index ["medical_staff_id"], name: "index_recording_sessions_on_medical_staff_id"
    t.index ["patient_id"], name: "index_recording_sessions_on_patient_id"
    t.index ["session_id"], name: "index_recording_sessions_on_session_id", unique: true
  end

  create_table "recordings", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "csv_file_path"
    t.string "diagnosis"
    t.bigint "doctor_id"
    t.text "doctor_notes"
    t.integer "duration_seconds"
    t.datetime "end_time"
    t.boolean "has_notes", default: false
    t.bigint "hospital_id", null: false
    t.text "interpretation"
    t.text "notes"
    t.bigint "patient_id", null: false
    t.datetime "reviewed_at"
    t.boolean "reviewed_by_doctor", default: false
    t.decimal "sample_rate"
    t.string "session_id"
    t.datetime "start_time"
    t.string "status"
    t.integer "total_samples"
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["doctor_id"], name: "index_recordings_on_doctor_id"
    t.index ["hospital_id"], name: "index_recordings_on_hospital_id"
    t.index ["patient_id", "reviewed_by_doctor"], name: "index_recordings_on_patient_id_and_reviewed_by_doctor"
    t.index ["patient_id"], name: "index_recordings_on_patient_id"
    t.index ["reviewed_by_doctor"], name: "index_recordings_on_reviewed_by_doctor"
    t.index ["session_id"], name: "index_recordings_on_session_id", unique: true
    t.index ["user_id"], name: "index_recordings_on_user_id"
  end

  create_table "upload_sessions", force: :cascade do |t|
    t.integer "chunk_size"
    t.json "chunks_received"
    t.integer "chunks_received_count"
    t.datetime "created_at", null: false
    t.string "file_name"
    t.string "file_sha256"
    t.bigint "file_size"
    t.bigint "recording_id", null: false
    t.string "session_id"
    t.string "status"
    t.integer "total_chunks"
    t.datetime "updated_at", null: false
    t.string "upload_id"
    t.index ["recording_id"], name: "index_upload_sessions_on_recording_id"
    t.index ["upload_id"], name: "index_upload_sessions_on_upload_id", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.date "date_of_birth"
    t.string "email"
    t.bigint "hospital_id"
    t.string "medical_record_number"
    t.string "name"
    t.string "password_digest"
    t.string "patient_identifier", limit: 12
    t.string "phone"
    t.string "role"
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["hospital_id"], name: "index_users_on_hospital_id"
    t.index ["patient_identifier"], name: "index_users_on_patient_identifier", unique: true
  end

  add_foreign_key "annotations", "recordings"
  add_foreign_key "annotations", "users", column: "created_by_id"
  add_foreign_key "biopotential_batches", "recordings"
  add_foreign_key "biopotential_samples", "recordings"
  add_foreign_key "ekg_markers", "recordings"
  add_foreign_key "ekg_markers", "users", column: "created_by_id"
  add_foreign_key "hospital_affiliations", "hospitals"
  add_foreign_key "hospital_affiliations", "medical_staffs"
  add_foreign_key "medical_staffs", "hospitals"
  add_foreign_key "medical_staffs", "users"
  add_foreign_key "patients", "users"
  add_foreign_key "qr_codes", "hospitals"
  add_foreign_key "qr_codes", "recording_sessions"
  add_foreign_key "recording_sessions", "medical_staffs"
  add_foreign_key "recording_sessions", "patients"
  add_foreign_key "recordings", "hospitals"
  add_foreign_key "recordings", "patients"
  add_foreign_key "recordings", "users"
  add_foreign_key "recordings", "users", column: "doctor_id"
  add_foreign_key "upload_sessions", "recordings"
  add_foreign_key "users", "hospitals"
end
