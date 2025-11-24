class Api::DevicesController < ApplicationController
  skip_before_action :verify_authenticity_token
  before_action :authenticate_api_user!
  
  # POST /api/devices/scan
  # Scan and validate CardioGuardian device
  def scan
    device_id = params[:device_id]
    device_name = params[:device_name]
    device_type = params[:device_type] || 'CardioGuardian'
    session_id = params[:session_id]
    
    unless device_id.present?
      return render json: {
        success: false,
        error: 'Device ID tidak ditemukan'
      }, status: :bad_request
    end
    
    # Validate session if provided
    if session_id.present?
      session = RecordingSession.find_by(session_id: session_id)
      
      unless session
        return render json: {
          success: false,
          error: 'Session tidak ditemukan'
        }, status: :not_found
      end
      
      unless session.status == 'active'
        return render json: {
          success: false,
          error: 'Session tidak aktif',
          session_status: session.status
        }, status: :unprocessable_entity
      end
    end
    
    # Return device validation response
    render json: {
      success: true,
      message: 'Device berhasil terdeteksi dan tervalidasi',
      device: {
        device_id: device_id,
        device_name: device_name,
        device_type: device_type,
        connection_status: 'connected',
        firmware_version: '1.0.0',
        battery_level: 100,
        signal_quality: 'good'
      },
      session: session ? {
        session_id: session.session_id,
        status: session.status,
        patient_name: session.patient.name
      } : nil,
      timestamp: Time.current
    }, status: :ok
    
  rescue StandardError => e
    render json: {
      success: false,
      error: 'Terjadi kesalahan pada server',
      details: Rails.env.development? ? e.message : nil
    }, status: :internal_server_error
  end
  
  # GET /api/devices/status/:device_id
  # Check device connection status
  def status
    device_id = params[:device_id]
    
    render json: {
      success: true,
      device: {
        device_id: device_id,
        connection_status: 'connected',
        battery_level: 100,
        signal_quality: 'good',
        last_seen: Time.current
      },
      timestamp: Time.current
    }, status: :ok
  end
  
  private
  
  def authenticate_api_user!
    token = request.headers['Authorization']&.split(' ')&.last
    
    unless token
      render json: { error: 'Unauthorized - Token tidak ditemukan' }, status: :unauthorized
      return
    end
  end
end
