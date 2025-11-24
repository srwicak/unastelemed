class Api::UploadsController < ApplicationController
  skip_before_action :verify_authenticity_token
  skip_before_action :authenticate_user!
  
  def init
    render json: { uploadId: "upload-#{SecureRandom.hex(16)}" }
  end
  
  def chunk
    render json: { success: true }
  end
  
  def complete
    render json: { success: true, recordingId: 1 }
  end
  
  def status
    render json: { status: "completed" }
  end
end
