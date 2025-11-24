class PatientsController < ApplicationController
  before_action :authenticate_user!
  before_action :require_medical_staff_or_manager, except: [:show, :medical_history, :recordings]
  before_action :set_patient, only: [:show, :edit, :update, :destroy, :medical_history, :recordings]
  before_action :authorize_patient_access, only: [:show, :medical_history, :recordings]

  def index
    # Hanya medical staff dan manager yang bisa lihat list semua pasien
    @patients = Patient.includes(:user).order(name: :asc).page(params[:page])
  end

  def show
    @sessions = @patient.recording_sessions.includes(:medical_staff, :qr_code).order(created_at: :desc)
  end

  def new
    @patient = Patient.new
    @patient.build_user
  end

  def create
    @patient = Patient.new(patient_params)
    
    if @patient.save
      redirect_to @patient, notice: 'Pasien berhasil dibuat.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @patient.update(patient_params)
      redirect_to @patient, notice: 'Data pasien berhasil diperbarui.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @patient.destroy
    redirect_to patients_url, notice: 'Pasien berhasil dihapus.'
  end

  def medical_history
    @sessions = @patient.recording_sessions.includes(:medical_staff, :recordings).order(created_at: :desc)
  end

  def recordings
    @recordings = @patient.recordings.includes(:recording_session).order(created_at: :desc)
  end

  private

  def require_medical_staff_or_manager
    unless current_user.medical_staff? || current_user.hospital_manager? || current_user.superuser?
      redirect_to root_path, alert: 'Akses ditolak. Halaman ini hanya untuk petugas medis.'
    end
  end

  def authorize_patient_access
    # Medical staff dan manager bisa akses semua patient
    return if current_user.medical_staff? || current_user.hospital_manager? || current_user.superuser?
    
    # Pasien hanya bisa akses data diri sendiri
    unless current_user.patient? && @patient.id == current_user.patient.id
      redirect_to root_path, alert: 'Akses ditolak'
    end
  end

  def set_patient
    @patient = Patient.find(params[:id])
  end

  def patient_params
    params.require(:patient).permit(
      :name, :date_of_birth, :gender, :phone_number, :address, 
      :emergency_contact, :blood_type, :allergies, :medical_conditions,
      user_attributes: [:email, :password, :password_confirmation]
    )
  end
end
