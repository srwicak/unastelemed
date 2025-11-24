class SessionsController < ApplicationController
  skip_before_action :authenticate_user!, only: [:new, :create, :hospital_login]

  def new
    redirect_to dashboard_path if current_user
  end
  
  # Login untuk hospital staff (manager, doctor, nurse)
  def hospital_login
    user = User.find_by(email: params[:email])
    
    if user&.authenticate(params[:password])
      # Hanya allow staff RS (bukan pasien)
      unless user.patient?
        session[:user_id] = user.id
        
        # Redirect berdasarkan role
        case user.role
        when 'nurse'
          redirect_to nurse_dashboard_path, notice: "Selamat datang, #{user.name}!"
        when 'doctor'
          redirect_to doctor_dashboard_path, notice: "Selamat datang, #{user.name}!"
        when 'hospital_manager'
          redirect_to hospital_manager_dashboard_path, notice: "Selamat datang, #{user.name}!"
        when 'superuser'
          redirect_to superuser_dashboard_path, notice: "Selamat datang, #{user.name}!"
        else
          redirect_to dashboard_path, notice: "Login berhasil!"
        end
      else
        flash[:alert] = "Akses ditolak. Gunakan halaman login pasien."
        redirect_to hospital_portal_path, alert: flash[:alert]
      end
    else
      flash[:alert] = "Email atau password salah"
      redirect_to hospital_portal_path, alert: flash[:alert]
    end
  end

  # Login universal - auto detect role
  def create
    user = User.find_by(email: params[:email])
    
    if user&.authenticate(params[:password])
      session[:user_id] = user.id
      
      # Redirect berdasarkan role
      case user.role
      when 'patient'
        redirect_to patient_dashboard_path, notice: "Selamat datang, #{user.name}!"
      when 'nurse'
        redirect_to nurse_dashboard_path, notice: "Selamat datang, #{user.name}!"
      when 'doctor'
        redirect_to doctor_dashboard_path, notice: "Selamat datang, #{user.name}!"
      when 'hospital_manager'
        redirect_to hospital_manager_dashboard_path, notice: "Selamat datang, #{user.name}!"
      when 'superuser'
        redirect_to superuser_dashboard_path, notice: "Selamat datang, #{user.name}!"
      else
        redirect_to dashboard_path, notice: "Login berhasil!"
      end
    else
      flash.now[:alert] = "Email atau password salah"
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    session[:user_id] = nil
    redirect_to root_path, notice: "Logout berhasil"
  end
  
  def forgot_password
  end
  
  def send_reset_password
    user = User.find_by(email: params[:email])
    
    if user
      # Kirim email reset password (implementasi email)
      flash[:notice] = "Instruksi reset password telah dikirim ke email Anda"
      redirect_to login_path
    else
      flash.now[:alert] = "Email tidak ditemukan"
      render :forgot_password
    end
  end
end
