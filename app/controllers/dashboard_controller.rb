class DashboardController < ApplicationController
  before_action :authenticate_user!
  before_action :set_medical_staff, only: [:doctor_dashboard, :nurse_dashboard]
  before_action :set_patient, only: [:patient_dashboard]

  def index
    if current_user&.medical_staff
      case current_user.medical_staff.role
      when 'doctor'
        redirect_to doctor_dashboard_path
      when 'nurse'
        redirect_to nurse_dashboard_path
      else
        redirect_to root_path, alert: 'Role tidak dikenali'
      end
    elsif current_user&.patient
      redirect_to patient_dashboard_path
    elsif current_user&.hospital_manager?
      redirect_to hospital_manager_dashboard_path
    elsif current_user&.superuser?
      redirect_to superuser_dashboard_path
    else
      redirect_to root_path, alert: 'Akses ditolak'
    end
  end

  def doctor_dashboard
    @recent_sessions = RecordingSession.includes(:patient, :medical_staff, :qr_code)
                                   .where(interpretation_completed: true)
                                   .order(created_at: :desc)
                                   .limit(10)

    @pending_sessions = RecordingSession.includes(:patient, :qr_code)
                                       .where(interpretation_completed: false)
                                       .order(created_at: :desc)
                                       .limit(10)

    @patients_count = Patient.count
    @sessions_count = RecordingSession.count
    @completed_interpretations = RecordingSession.where(interpretation_completed: true).count

    @recent_interpretations = RecordingSession.includes(:patient, :medical_staff)
                                            .where.not(doctor_notes: nil)
                                            .order(updated_at: :desc)
                                            .limit(5)
  end

  def nurse_dashboard
    @active_sessions = RecordingSession.includes(:patient, :qr_code)
                                      .where(status: 'active')
                                      .order(created_at: :desc)

    @completed_sessions = RecordingSession.includes(:patient, :qr_code)
                                       .where(status: 'completed')
                                       .order(created_at: :desc)
                                       .limit(10)

    @patients = Patient.order(name: :asc)
    
    @today_sessions = RecordingSession.where(created_at: Date.current.all_day).count
    @active_count = RecordingSession.where(status: 'active').count
  end

  def patient_dashboard
    @my_sessions = RecordingSession.includes(:medical_staff, :qr_code)
                                .where(patient: current_user.patient)
                                .order(created_at: :desc)

    @completed_sessions = @my_sessions.where(status: 'completed')
                                   .where.not(interpretation_completed: false)
                                   .limit(5)

    @pending_sessions = @my_sessions.where(status: 'active')
                                   .or(@my_sessions.where(interpretation_completed: false))

    @latest_interpretation = @my_sessions.where.not(doctor_notes: nil)
                                        .order(updated_at: :desc)
                                        .first
  end

  def hospital_manager_dashboard
    unless current_user&.hospital_manager?
      redirect_to root_path, alert: 'Akses ditolak'
      return
    end

    @total_doctors = User.doctors.count
    @total_nurses = User.nurses.count
    @total_patients = Patient.count
    @total_sessions = RecordingSession.count
    
    @recent_staff = User.where(role: ['doctor', 'nurse'])
                        .order(created_at: :desc)
                        .limit(5)
    
    @recent_sessions = RecordingSession.includes(:patient, :medical_staff)
                                      .order(created_at: :desc)
                                      .limit(10)
    
    @hospitals = Hospital.includes(:users).all
  end

  def superuser_dashboard
    unless current_user&.superuser?
      redirect_to root_path, alert: 'Akses ditolak'
      return
    end

    @total_hospitals = Hospital.count
    @total_users = User.count
    @total_managers = User.hospital_managers.count
    @total_staff = User.where(role: ['doctor', 'nurse']).count
    
    @recent_users = User.order(created_at: :desc).limit(10)
    @recent_hospitals = Hospital.order(created_at: :desc).limit(5)
  end

  def create_session
    @session = RecordingSession.new(session_params)
    @session.status = 'active'
    @session.started_at = Time.current
    
    if @session.save
      # Dapatkan patient dari session
      patient = @session.patient
      
      # Get QR code parameters from form
      max_duration_minutes = if params[:qr_code][:max_duration_minutes] == 'custom'
                               params[:qr_code][:custom_duration_minutes].to_i
                             else
                               params[:qr_code][:max_duration_minutes].to_i
                             end
      
      valid_hours = params[:qr_code][:valid_hours].to_f
      
      @qr_code = QrCode.create!(
        code: SecureRandom.hex(16),
        recording_session: @session,
        hospital_id: current_user.hospital_id || patient.user.hospital_id,
        healthcare_provider: current_user,
        patient: patient,
        valid_from: Time.current,
        valid_until: (valid_hours * 3600).seconds.from_now,
        max_duration_minutes: max_duration_minutes,
        is_used: false
      )
      
      redirect_to nurse_dashboard_path, notice: 'Sesi pemeriksaan berhasil dibuat'
    else
      redirect_to nurse_dashboard_path, alert: 'Gagal membuat sesi: ' + @session.errors.full_messages.join(', ')
    end
  end

  def view_recording
    @recording = Recording.find_by(session_id: params[:session_id])
    
    unless @recording
      redirect_to dashboard_path, alert: 'Recording tidak ditemukan'
      return
    end
    @session = @recording.recording_session
    
    unless can_access_recording?(@recording)
      redirect_to dashboard_path, alert: 'Akses ditolak'
      return
    end

    # Load batch data instead of individual samples
    @batches = @recording.biopotential_batches.ordered.limit(100) # Limit for performance
    @interpretation = @session&.interpretation_completed? ? @session.doctor_notes : nil
  end

  def add_interpretation
    @session = RecordingSession.find(params[:id])
    
    unless current_user.medical_staff&.doctor?
      redirect_to dashboard_path, alert: 'Hanya dokter yang dapat menambahkan interpretasi'
      return
    end

    if @session.update(interpretation_params.merge(interpretation_completed: true))
      redirect_to doctor_dashboard_path, notice: 'Interpretasi berhasil ditambahkan'
    else
      redirect_to doctor_dashboard_path, alert: 'Gagal menambahkan interpretasi'
    end
  end

  def complete_session
    @session = RecordingSession.find(params[:id])
    
    unless current_user.medical_staff&.nurse?
      redirect_to dashboard_path, alert: 'Hanya perawat yang dapat menyelesaikan sesi'
      return
    end

    if @session.update(status: 'completed')
      redirect_to nurse_dashboard_path, notice: 'Sesi berhasil diselesaikan'
    else
      redirect_to nurse_dashboard_path, alert: 'Gagal menyelesaikan sesi'
    end
  end

  private

  def set_medical_staff
    unless current_user&.medical_staff
      redirect_to root_path, alert: 'Akses ditolak'
      return
    end
    @medical_staff = current_user.medical_staff
  end

  def set_patient
    unless current_user&.patient
      redirect_to root_path, alert: 'Akses ditolak'
      return
    end
    @patient = current_user.patient
  end

  def session_params
    params.require(:recording_session).permit(:patient_id, :medical_staff_id, :notes)
  end

  def interpretation_params
    params.require(:recording_session).permit(:doctor_notes, :diagnosis, :recommendations)
  end

  def can_access_recording?(recording)
    return true if current_user.medical_staff
    return true if current_user.patient && recording.recording_session.patient == current_user.patient
    false
  end
end