class Api::SessionsController < ApplicationController
  skip_before_action :verify_authenticity_token
  before_action :authenticate_api_user!, except: [:validate_qr]
  
  # POST /api/sessions/validate_qr
  # Validates QR code payload from mobile app
  def validate_qr
    payload = params[:payload]
    
    unless payload
      return render json: { 
        success: false, 
        error: 'Payload tidak ditemukan' 
      }, status: :bad_request
    end
    
    begin
      # Parse JSON payload from QR code
      qr_data = JSON.parse(payload)
      
      # Validate required fields
      required_fields = ['code', 'hospital_id', 'healthcare_provider_id', 'valid_until', 'max_duration_minutes']
      missing_fields = required_fields - qr_data.keys
      
      if missing_fields.any?
        return render json: {
          success: false,
          error: "Field yang diperlukan tidak lengkap: #{missing_fields.join(', ')}"
        }, status: :bad_request
      end
      
      # Find QR code by code
      qr_code = QrCode.find_by(code: qr_data['code'])
      
      unless qr_code
        return render json: {
          success: false,
          error: 'QR code tidak ditemukan'
        }, status: :not_found
      end
      
      # Validate QR code status
      if qr_code.is_used
        return render json: {
          success: false,
          error: 'QR code sudah digunakan',
          used_at: qr_code.used_at
        }, status: :unprocessable_entity
      end
      
      if qr_code.expired?
        return render json: {
          success: false,
          error: 'QR code sudah expired',
          valid_until: qr_code.valid_until
        }, status: :unprocessable_entity
      end
      
      if !qr_code.valid_now?
        return render json: {
          success: false,
          error: 'QR code belum valid atau sudah tidak berlaku',
          valid_from: qr_code.valid_from,
          valid_until: qr_code.valid_until
        }, status: :unprocessable_entity
      end
      
      # Validate hospital
      hospital = Hospital.find_by(id: qr_data['hospital_id'])
      unless hospital
        return render json: {
          success: false,
          error: 'Hospital tidak ditemukan'
        }, status: :not_found
      end
      
      # QR code is valid, return session information
      session_data = {
        success: true,
        message: 'QR code valid',
        qr_code: {
          id: qr_code.id,
          code: qr_code.code,
          valid_until: qr_code.valid_until,
          max_duration_minutes: qr_code.max_duration_minutes,
          max_duration_seconds: qr_code.duration_in_seconds
        },
        session: {
          session_id: qr_code.recording_session&.session_id,
          status: qr_code.recording_session&.status,
          started_at: qr_code.recording_session&.started_at
        },
        patient: {
          id: qr_code.patient&.id,
          patient_identifier: qr_code.patient&.patient_identifier,
          name: qr_code.patient&.name,
          date_of_birth: qr_code.patient&.date_of_birth,
          gender: qr_code.patient&.gender
        },
        hospital: {
          id: hospital.id,
          name: hospital.name,
          code: hospital.code
        },
        healthcare_provider: {
          id: qr_code.healthcare_provider_id,
          type: qr_code.healthcare_provider_type,
          name: qr_code.healthcare_provider&.name || qr_code.healthcare_provider&.full_name
        },
        device_type: 'CardioGuardian',
        timestamp: Time.current
      }
      
      render json: session_data, status: :ok
      
    rescue JSON::ParserError => e
      render json: {
        success: false,
        error: 'Format payload tidak valid',
        details: e.message
      }, status: :bad_request
    rescue StandardError => e
      render json: {
        success: false,
        error: 'Terjadi kesalahan pada server',
        details: Rails.env.development? ? e.message : nil
      }, status: :internal_server_error
    end
  end
  
  private
  
  def authenticate_api_user!
    # Implement your API authentication logic here
    # This could be JWT, API key, or session-based
    token = request.headers['Authorization']&.split(' ')&.last
    
    unless token
      render json: { error: 'Unauthorized - Token tidak ditemukan' }, status: :unauthorized
      return
    end
    
    # Add your token validation logic here
    # For now, we'll skip detailed validation
  end
end
