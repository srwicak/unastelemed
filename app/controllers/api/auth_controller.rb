class Api::AuthController < ApplicationController
  skip_before_action :verify_authenticity_token
  skip_before_action :authenticate_user!, except: [:profile, :update_profile, :logout]
  before_action :authenticate_request, only: [:profile, :update_profile]
  
  def register
    user = User.new(user_params)
    # Default role to 'patient' if not provided
    user.role ||= 'patient'
    
    if user.save
      token = user.generate_jwt_token
      render json: {
        success: true,
        message: 'Registration successful',
        data: {
          user: user_data(user),
          token: token
        }
      }, status: :created
    else
      render json: {
        success: false,
        message: 'Registration failed',
        errors: user.errors.full_messages
      }, status: :unprocessable_entity
    end
  end
  
  def login
    user = User.find_by(email: params[:email]&.downcase)
    
    if user&.authenticate(params[:password])
      token = user.generate_jwt_token
      render json: {
        success: true,
        message: 'Login successful',
        data: {
          user: user_data(user),
          token: token
        }
      }, status: :ok
    else
      render json: {
        success: false,
        message: 'Invalid email or password'
      }, status: :unauthorized
    end
  end
  
  def profile
    render json: {
      success: true,
      data: {
        user: user_data(@current_user)
      }
    }, status: :ok
  end
  
  def update_profile
    if @current_user.update(user_update_params)
      render json: {
        success: true,
        message: 'Profile updated successfully',
        data: {
          user: user_data(@current_user)
        }
      }, status: :ok
    else
      render json: {
        success: false,
        message: 'Profile update failed',
        errors: @current_user.errors.full_messages
      }, status: :unprocessable_entity
    end
  end
  
  def validate_token
    if authenticate_request
      render json: {
        success: true,
        message: 'Token is valid',
        data: {
          user: user_data(@current_user)
        }
      }, status: :ok
    else
      render json: {
        success: false,
        message: 'Invalid or expired token'
      }, status: :unauthorized
    end
  end
  
  def logout
    # For JWT, we can't really invalidate the token server-side
    # But we can log the logout event and return success
    if authenticate_request
      # Log logout event if needed
      Rails.logger.info "User #{@current_user.id} logged out"
    end
    
    render json: {
      success: true,
      message: 'Logout successful'
    }, status: :ok
  end
  
  def forgot_password
    user = User.find_by(email: params[:email]&.downcase)
    
    if user.present?
      # In a real app, you'd send an email with reset instructions
      # For now, we'll just return success
      Rails.logger.info "Password reset requested for #{user.email}"
      
      render json: {
        success: true,
        message: 'Password reset instructions have been sent to your email'
      }, status: :ok
    else
      render json: {
        success: false,
        message: 'Email not found'
      }, status: :not_found
    end
  end
  
  private
  
  def user_params
    # Handle both flat params and nested auth params
    auth_params = params[:auth] || params
    
    auth_params.permit(
      :email, 
      :password, 
      :password_confirmation, 
      :name, 
      :phone, 
      :role, 
      :date_of_birth, 
      :medical_record_number,
      :hospital_id
    )
  end
  
  def user_update_params
    params.permit(
      :name, 
      :phone, 
      :date_of_birth, 
      :medical_record_number,
      :hospital_id
    )
  end
  
  def user_data(user)
    {
      id: user.id,
      email: user.email,
      name: user.name,
      phone: user.phone,
      role: user.role,
      patient_identifier: user.patient_identifier,
      date_of_birth: user.date_of_birth,
      medical_record_number: user.medical_record_number,
      hospital_id: user.hospital_id,
      hospital_name: user.hospital&.name,
      created_at: user.created_at,
      updated_at: user.updated_at
    }
  end
  
  def authenticate_request
    header = request.headers['Authorization']
    token = header&.split(' ')&.last
    
    return false unless token.present?
    
    begin
      decoded = JWT.decode(token, Rails.application.credentials.secret_key_base, true, { algorithm: 'HS256' })
      user_id = decoded[0]['user_id']
      @current_user = User.find_by(id: user_id)
      
      return false unless @current_user.present?
      
      # Check if token is expired (additional safety check)
      exp = decoded[0]['exp']
      return false if exp.present? && Time.at(exp) < Time.current
      
      true
    rescue JWT::DecodeError, JWT::ExpiredSignature
      false
    end
  end
end
