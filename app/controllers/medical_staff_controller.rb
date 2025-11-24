class MedicalStaffController < ApplicationController
  before_action :authenticate_user!
  before_action :require_manager_or_superuser
  before_action :set_medical_staff, only: [:show]

  def index
    @medical_staffs = MedicalStaff.includes(:user, :hospital)
                                   .where(approval_status: 'approved')
                                   .order(created_at: :desc)
                                   .page(params[:page])
    
    # Filter berdasarkan hospital jika hospital manager
    if current_user.hospital_manager?
      @medical_staffs = @medical_staffs.where(hospital_id: current_user.hospital_id)
    end
  end

  def show
    unless can_access_staff?
      redirect_to medical_staff_path, alert: 'Akses ditolak'
    end
  end

  def doctors
    @doctors = MedicalStaff.includes(:user, :hospital)
                           .where(role: 'doctor', approval_status: 'approved')
                           .order(created_at: :desc)
                           .page(params[:page])
    
    if current_user.hospital_manager?
      @doctors = @doctors.where(hospital_id: current_user.hospital_id)
    end
  end

  def nurses
    @nurses = MedicalStaff.includes(:user, :hospital)
                          .where(role: 'nurse', approval_status: 'approved')
                          .order(created_at: :desc)
                          .page(params[:page])
    
    if current_user.hospital_manager?
      @nurses = @nurses.where(hospital_id: current_user.hospital_id)
    end
  end

  private

  def require_manager_or_superuser
    unless current_user.hospital_manager? || current_user.superuser?
      redirect_to root_path, alert: 'Akses ditolak. Halaman ini hanya untuk hospital manager dan superuser.'
    end
  end

  def set_medical_staff
    @medical_staff = MedicalStaff.find(params[:id])
  end

  def can_access_staff?
    return true if current_user.superuser?
    return true if current_user.hospital_manager? && @medical_staff.hospital_id == current_user.hospital_id
    false
  end
end
