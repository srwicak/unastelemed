class HospitalsController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_superuser!, only: [:new, :create, :edit, :update, :destroy]
  before_action :set_hospital, only: [:show, :edit, :update, :destroy]

  def index
    if current_user.superuser?
      @hospitals = Hospital.all.order(created_at: :desc)
    elsif current_user.hospital_manager?
      @hospitals = Hospital.where(id: current_user.hospital_id)
    else
      redirect_to root_path, alert: 'Akses ditolak'
    end
  end

  def show
    unless can_access_hospital?
      redirect_to hospitals_path, alert: 'Akses ditolak'
      return
    end
    
    @staff_count = User.where(hospital_id: @hospital.id, role: ['doctor', 'nurse']).count
    @manager_count = User.where(hospital_id: @hospital.id, role: 'hospital_manager').count
    @recent_staff = User.where(hospital_id: @hospital.id)
                        .where(role: ['doctor', 'nurse'])
                        .order(created_at: :desc)
                        .limit(10)
  end

  def new
    @hospital = Hospital.new
    @manager = User.new
  end

  def create
    @hospital = Hospital.new(hospital_params)
    
    ActiveRecord::Base.transaction do
      if @hospital.save
        # Buat Hospital Manager User
        @manager = User.new(manager_params)
        @manager.role = 'hospital_manager'
        @manager.hospital_id = @hospital.id
        
        if @manager.save
          redirect_to hospitals_path, notice: "Rumah Sakit #{@hospital.name} berhasil didaftarkan!"
        else
          raise ActiveRecord::Rollback
        end
      end
    end
    
    if @hospital.persisted? && @manager.persisted?
      # Success - already redirected
    else
      flash.now[:alert] = 'Gagal mendaftarkan rumah sakit: ' + 
                          (@hospital.errors.full_messages + @manager.errors.full_messages).join(', ')
      render :new
    end
  end

  def edit
  end

  def update
    if @hospital.update(hospital_params)
      redirect_to @hospital, notice: 'Data rumah sakit berhasil diupdate.'
    else
      render :edit
    end
  end

  def destroy
    @hospital.destroy
    redirect_to hospitals_path, notice: 'Rumah sakit berhasil dihapus.'
  end
  
  # Action untuk Hospital Manager tambah medical staff
  def add_staff
    @hospital = current_user.hospital
    unless @hospital
      redirect_to root_path, alert: 'Anda tidak terdaftar di rumah sakit manapun'
      return
    end
    
    @staff_user = User.new
    @medical_staff = MedicalStaff.new
  end
  
  def create_staff
    @hospital = current_user.hospital
    
    unless @hospital
      redirect_to root_path, alert: 'Anda tidak terdaftar di rumah sakit manapun'
      return
    end
    
    @staff_user = User.new(staff_user_params)
    @staff_user.hospital_id = @hospital.id
    
    ActiveRecord::Base.transaction do
      if @staff_user.save
        @medical_staff = @staff_user.build_medical_staff(medical_staff_params)
        @medical_staff.hospital_id = @hospital.id
        @medical_staff.approval_status = 'approved'
        @medical_staff.approved_by = current_user.id
        @medical_staff.approved_at = Time.current
        
        if @medical_staff.save
          redirect_to hospital_manager_dashboard_path, 
                      notice: "#{@medical_staff.full_title} berhasil ditambahkan!"
        else
          raise ActiveRecord::Rollback
        end
      end
    end
    
    if @staff_user.persisted? && @medical_staff&.persisted?
      # Success - already redirected
    else
      flash.now[:alert] = 'Gagal menambahkan staff: ' + 
                          (@staff_user.errors.full_messages + 
                           (@medical_staff&.errors&.full_messages || [])).join(', ')
      render :add_staff
    end
  end

  private

  def set_hospital
    @hospital = Hospital.find(params[:id])
  end

  def ensure_superuser!
    unless current_user&.superuser?
      redirect_to root_path, alert: 'Akses ditolak. Hanya Superuser yang dapat mengakses halaman ini.'
    end
  end
  
  def can_access_hospital?
    return true if current_user.superuser?
    return true if current_user.hospital_id == @hospital.id
    false
  end

  def hospital_params
    params.require(:hospital).permit(:name, :code, :address, :phone, :email)
  end
  
  def manager_params
    params.require(:manager).permit(:name, :email, :phone, :password, :password_confirmation)
  end
  
  def staff_user_params
    params.require(:staff_user).permit(:name, :email, :phone, :password, :password_confirmation, :role)
  end
  
  def medical_staff_params
    params.require(:medical_staff).permit(:name, :role, :license_number, :specialization, :phone)
  end
end
