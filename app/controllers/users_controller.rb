class UsersController < ApplicationController
  skip_before_action :authenticate_user!, only: [:new, :create]
  
  def new
    @user = User.new
    @user.build_patient
  end
  
  def create
    @user = User.new(user_params)
    @user.role = 'patient'
    
    if @user.save
      session[:user_id] = @user.id
      redirect_to patient_dashboard_path, notice: 'Registrasi berhasil! Selamat datang di Medical Data Management System.'
    else
      render :new, status: :unprocessable_entity
    end
  end
  
  private
  
  def user_params
    params.require(:user).permit(
      :name, :email, :password, :password_confirmation,
      patient_attributes: [
        :name, :date_of_birth, :gender, :phone_number, 
        :address, :emergency_contact, :blood_type, :allergies, :medical_conditions
      ]
    )
  end
end