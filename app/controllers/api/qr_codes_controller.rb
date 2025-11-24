class Api::QrCodesController < ApplicationController
  skip_before_action :verify_authenticity_token
  skip_before_action :authenticate_user!
  before_action :set_qr_code, only: [:show, :update, :validate, :use]
  
  def index
    @qr_codes = QrCode.includes(:hospital, :healthcare_provider, :patient)
                      .order(created_at: :desc)
                      .page(params[:page])
                      .per(params[:per_page] || 20)
    
    render json: {
      success: true,
      data: {
        qr_codes: @qr_codes.map { |qr| qr_code_data(qr) },
        pagination: pagination_data(@qr_codes)
      }
    }, status: :ok
  end
  
  def show
    render json: {
      success: true,
      data: {
        qr_code: qr_code_data(@qr_code)
      }
    }, status: :ok
  end
  
  def create
    @qr_code = QrCode.new(qr_code_params)
    
    if @qr_code.save
      render json: {
        success: true,
        message: 'QR Code created successfully',
        data: {
          qr_code: qr_code_data(@qr_code),
          svg: @qr_code.to_qr_svg
        }
      }, status: :created
    else
      render json: {
        success: false,
        message: 'QR Code creation failed',
        errors: @qr_code.errors.full_messages
      }, status: :unprocessable_entity
    end
  end
  
  def update
    if @qr_code.update(qr_code_update_params)
      render json: {
        success: true,
        message: 'QR Code updated successfully',
        data: {
          qr_code: qr_code_data(@qr_code)
        }
      }, status: :ok
    else
      render json: {
        success: false,
        message: 'QR Code update failed',
        errors: @qr_code.errors.full_messages
      }, status: :unprocessable_entity
    end
  end
  
  def validate
    # This endpoint can be called without authentication for mobile app validation
    code = params[:code] || @qr_code&.code
    
    unless code.present?
      return render json: {
        success: false,
        message: 'QR Code is required'
      }, status: :bad_request
    end
    
    @qr_code ||= QrCode.find_by(code: code)
    
    unless @qr_code
      return render json: {
        success: false,
        message: 'Invalid QR Code'
      }, status: :not_found
    end
    
    if @qr_code.valid_now?
      render json: {
        success: true,
        message: 'QR Code is valid',
        data: {
          valid: true,
          qr_code: {
            code: @qr_code.code,
            hospital_id: @qr_code.hospital_id,
            healthcare_provider_id: @qr_code.healthcare_provider_id,
            healthcare_provider_type: @qr_code.healthcare_provider_type,
            valid_until: @qr_code.valid_until,
            max_duration_minutes: @qr_code.max_duration_minutes,
            duration_in_seconds: @qr_code.duration_in_seconds
          },
          session_info: {
            can_start: true,
            duration_minutes: @qr_code.max_duration_minutes
          },
          healthcare_provider: healthcare_provider_data(@qr_code)
        }
      }, status: :ok
    else
      if @qr_code.expired?
        render json: {
          success: false,
          message: 'QR Code has expired',
          data: {
            valid: false,
            expired_at: @qr_code.valid_until
          }
        }, status: :gone
      elsif @qr_code.is_used?
        render json: {
          success: false,
          message: 'QR Code has already been used',
          data: {
            valid: false
          }
        }, status: :conflict
      else
        render json: {
          success: false,
          message: 'QR Code is not valid at this time',
          data: {
            valid: false,
            valid_from: @qr_code.valid_from,
            valid_until: @qr_code.valid_until
          }
        }, status: :bad_request
      end
    end
  end
  
  def validate_by_code
    # Handle multiple parameter formats
    # 1. Direct code parameter: params[:code]
    # 2. Nested in qr_code: params[:qr_code][:validation_code]
    # 3. JSON string in code parameter
    
    qr_params = params[:qr_code] || {}
    code = params[:code] || qr_params[:validation_code]
    
    unless code.present?
      return render json: {
        success: false,
        message: 'QR Code is required'
      }, status: :bad_request
    end
    
    # If code is JSON string, extract the validation_code
    validation_code = code
    begin
      if code.is_a?(String) && code.start_with?('{')
        parsed_code = JSON.parse(code)
        validation_code = parsed_code['validation_code']
      end
    rescue JSON::ParserError
      # If parsing fails, use the code as-is
    end
    
    @qr_code = QrCode.find_by(code: validation_code)
    
    unless @qr_code
      return render json: {
        success: false,
        message: 'Invalid QR Code'
      }, status: :not_found
    end
    
    if @qr_code.valid_now?
      render json: {
        success: true,
        message: 'QR Code is valid',
        data: {
          valid: true,
          qr_code: {
            code: @qr_code.code,
            hospital_id: @qr_code.hospital_id,
            healthcare_provider_id: @qr_code.healthcare_provider_id,
            healthcare_provider_type: @qr_code.healthcare_provider_type,
            valid_until: @qr_code.valid_until,
            max_duration_minutes: @qr_code.max_duration_minutes,
            duration_in_seconds: @qr_code.duration_in_seconds
          },
          session_info: {
            can_start: true,
            duration_minutes: @qr_code.max_duration_minutes
          },
          healthcare_provider: healthcare_provider_data(@qr_code)
        }
      }, status: :ok
    else
      if @qr_code.expired?
        render json: {
          success: false,
          message: 'QR Code has expired',
          data: {
            valid: false,
            expired_at: @qr_code.valid_until
          }
        }, status: :gone
      elsif @qr_code.is_used?
        render json: {
          success: false,
          message: 'QR Code has already been used',
          data: {
            valid: false
          }
        }, status: :conflict
      else
        render json: {
          success: false,
          message: 'QR Code is not valid at this time',
          data: {
            valid: false,
            valid_from: @qr_code.valid_from,
            valid_until: @qr_code.valid_until
          }
        }, status: :bad_request
      end
    end
  end
  
  def use
    if @qr_code.valid_now?
      @qr_code.use!
      render json: {
        success: true,
        message: 'QR Code marked as used',
        data: {
          qr_code: qr_code_data(@qr_code)
        }
      }, status: :ok
    else
      render json: {
        success: false,
        message: 'Cannot use QR Code - it is not valid'
      }, status: :bad_request
    end
  end
  
  private
  
  def set_qr_code
    @qr_code = QrCode.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: {
      success: false,
      message: 'QR Code not found'
    }, status: :not_found
  end
  
  def qr_code_params
    params.permit(
      :hospital_id,
      :healthcare_provider_id,
      :healthcare_provider_type,
      :patient_id,
      :patient_type,
      :valid_from,
      :valid_until,
      :max_duration_minutes,
      :code
    )
  end
  
  def qr_code_update_params
    params.permit(
      :valid_from,
      :valid_until,
      :max_duration_minutes,
      :is_used
    )
  end
  
  def healthcare_provider_data(qr_code)
    provider = qr_code.healthcare_provider
    return nil unless provider.present?
    
    {
      id: provider.id,
      name: provider.name,
      email: provider.email,
      role: provider.role,
      hospital_id: provider.hospital_id,
      hospital_name: provider.hospital&.name
    }
  end
  
  def qr_code_data(qr_code)
    {
      id: qr_code.id,
      code: qr_code.code,
      hospital_id: qr_code.hospital_id,
      hospital_name: qr_code.hospital&.name,
      healthcare_provider_id: qr_code.healthcare_provider_id,
      healthcare_provider_type: qr_code.healthcare_provider_type,
      patient_id: qr_code.patient_id,
      patient_type: qr_code.patient_type,
      valid_from: qr_code.valid_from,
      valid_until: qr_code.valid_until,
      max_duration_minutes: qr_code.max_duration_minutes,
      duration_in_seconds: qr_code.duration_in_seconds,
      is_used: qr_code.is_used,
      expired: qr_code.expired?,
      valid_now: qr_code.valid_now?,
      svg: qr_code.to_qr_svg,
      created_at: qr_code.created_at,
      updated_at: qr_code.updated_at
    }
  end
  
  def pagination_data(scope)
    {
      current_page: scope.current_page,
      next_page: scope.next_page,
      prev_page: scope.prev_page,
      total_pages: scope.total_pages,
      total_count: scope.total_count
    }
  end
end
