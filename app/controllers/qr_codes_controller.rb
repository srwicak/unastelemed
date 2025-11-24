class QrCodesController < ApplicationController
  before_action :authenticate_user!
  before_action :require_medical_staff, except: [:show, :show_by_session]
  before_action :set_qr_code, only: [:show, :use, :session_data]

  def index
    # Hanya untuk nurse/doctor/hospital_manager/superuser
    if current_user.medical_staff
      @qr_codes = QrCode.where(healthcare_provider: current_user)
                        .includes(:patient, :recording_session)
                        .order(created_at: :desc)
                        .limit(50)
      base_scope = QrCode.where(healthcare_provider: current_user)
    elsif current_user.hospital_manager? || current_user.superuser?
      @qr_codes = QrCode.includes(:patient, :recording_session)
                        .order(created_at: :desc)
                        .limit(50)
      base_scope = QrCode.all
    else
      redirect_to root_path, alert: 'Akses ditolak'
      return
    end
    
    # Calculate statistics
    @total_count = base_scope.count
    @used_count = base_scope.where(is_used: true).count
    @active_count = base_scope.where(is_used: false).where('valid_until > ?', Time.current).count
    @expired_count = base_scope.where('valid_until < ?', Time.current).count
  end

  def show
    # Pasien bisa lihat QR code mereka sendiri, medical staff bisa lihat semua
    unless can_view_qr_code?(@qr_code)
      redirect_to root_path, alert: 'Akses ditolak'
      return
    end
  end
  
  def show_by_session
    session = RecordingSession.find_by!(session_id: params[:session_id])
    @qr_code = session.qr_code
    
    unless can_view_qr_code?(@qr_code)
      redirect_to root_path, alert: 'Akses ditolak'
      return
    end
    
    render :show
  end

  def new
    # Hanya untuk nurse
    unless current_user.medical_staff&.nurse?
      redirect_to root_path, alert: 'Hanya perawat yang dapat membuat QR code'
      return
    end
    
    @qr_code = QrCode.new
    @patients = Patient.order(name: :asc)
  end

  def create
    # QR code creation dilakukan via dashboard#create_session
    redirect_to nurse_dashboard_path, alert: 'Buat QR code melalui form "Buat Sesi Pemeriksaan"'
  end

  def use
    if @qr_code.is_used?
      render json: { error: 'QR code sudah digunakan' }, status: :unprocessable_entity
      return
    end

    if @qr_code.expired?
      render json: { error: 'QR code sudah expired' }, status: :unprocessable_entity
      return
    end

    @qr_code.update!(is_used: true, used_at: Time.current)
    render json: { message: 'QR code berhasil digunakan', qr_code: @qr_code }, status: :ok
  end

  def session_data
    render json: {
      session: @qr_code.recording_session,
      patient: @qr_code.patient,
      qr_code: @qr_code.qr_payload
    }
  end

  private

  def require_medical_staff
    unless current_user.medical_staff? || current_user.hospital_manager? || current_user.superuser?
      redirect_to root_path, alert: 'Akses ditolak. Halaman ini hanya untuk petugas medis.'
    end
  end

  def set_qr_code
    @qr_code = QrCode.find(params[:id])
  end

  def can_view_qr_code?(qr_code)
    return true if current_user.medical_staff? || current_user.hospital_manager? || current_user.superuser?
    return true if current_user.patient? && qr_code.patient == current_user.patient
    false
  end
end
