class MedicalStaffRegistrationsController < ApplicationController
  skip_before_action :authenticate_user!, only: [:new, :create]
  before_action :authenticate_manager!, only: [:index, :approve, :reject]
  before_action :set_registration, only: [:show, :approve, :reject]
  
  def new
    @user = User.new
    @medical_staff = MedicalStaff.new
    @hospitals = Hospital.all
  end
  
  def create
    @user = User.new(user_params)
    @user.role = user_params[:role] # doctor atau nurse
    
    ActiveRecord::Base.transaction do
      if @user.save
        @medical_staff = @user.build_medical_staff(medical_staff_params)
        @medical_staff.approval_status = 'pending'
        
        if @medical_staff.save
          # Kirim notifikasi ke hospital manager (opsional)
          # TODO: Send email notification
          
          redirect_to root_path, notice: 'Pendaftaran berhasil! Menunggu persetujuan dari Hospital Manager.'
        else
          raise ActiveRecord::Rollback
        end
      end
    end
    
    if @user.persisted? && @medical_staff.persisted?
      # Success - already redirected
    else
      @hospitals = Hospital.all
      flash.now[:alert] = 'Pendaftaran gagal: ' + (@user.errors.full_messages + @medical_staff.errors.full_messages).join(', ')
      render :new
    end
  end
  
  def index
    @pending_registrations = MedicalStaff.includes(:user, :hospital)
                                         .where(approval_status: 'pending')
                                         .order(created_at: :desc)
    
    @approved_registrations = MedicalStaff.includes(:user, :hospital)
                                          .where(approval_status: 'approved')
                                          .order(approved_at: :desc)
                                          .limit(20)
    
    @rejected_registrations = MedicalStaff.includes(:user, :hospital)
                                          .where(approval_status: 'rejected')
                                          .order(updated_at: :desc)
                                          .limit(10)
  end
  
  def show
    # Detail registrasi
  end
  
  def approve
    if @medical_staff.update(
      approval_status: 'approved',
      approved_by: current_user.id,
      approved_at: Time.current
    )
      # TODO: Kirim email notifikasi ke user
      redirect_to medical_staff_registrations_path, notice: "#{@medical_staff.name} telah disetujui sebagai #{@medical_staff.role}."
    else
      redirect_to medical_staff_registrations_path, alert: 'Gagal menyetujui pendaftaran.'
    end
  end
  
  def reject
    if @medical_staff.update(
      approval_status: 'rejected',
      approved_by: current_user.id,
      approved_at: Time.current
    )
      # TODO: Kirim email notifikasi ke user
      redirect_to medical_staff_registrations_path, notice: "Pendaftaran #{@medical_staff.name} telah ditolak."
    else
      redirect_to medical_staff_registrations_path, alert: 'Gagal menolak pendaftaran.'
    end
  end
  
  private
  
  def set_registration
    @medical_staff = MedicalStaff.find(params[:id])
  end
  
  def authenticate_manager!
    unless current_user&.hospital_manager? || current_user&.superuser?
      redirect_to root_path, alert: 'Akses ditolak. Hanya Hospital Manager yang dapat mengakses halaman ini.'
    end
  end
  
  def user_params
    params.require(:user).permit(:name, :email, :password, :password_confirmation, :role, :phone, :hospital_id)
  end
  
  def medical_staff_params
    params.require(:medical_staff).permit(:name, :license_number, :specialization, :role, :hospital_id, :phone)
  end
end
