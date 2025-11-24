class Api::EkgMarkersController < ApplicationController
  skip_before_action :verify_authenticity_token
  before_action :authenticate_request, except: [:index, :show]
  before_action :set_recording, only: [:index, :create]
  before_action :set_marker, only: [:show, :update, :destroy]
  
  # GET /api/recordings/:recording_id/markers
  def index
    @markers = @recording.ekg_markers
                        .includes(:created_by)
                        .ordered
    
    # Filter by type if provided
    @markers = @markers.by_type(params[:type]) if params[:type].present?
    
    # Filter by severity if provided
    @markers = @markers.by_severity(params[:severity]) if params[:severity].present?
    
    render json: {
      success: true,
      data: {
        recording_id: @recording.id,
        total_markers: @markers.count,
        markers: @markers.map { |marker| marker_data(marker) }
      }
    }, status: :ok
  end
  
  # GET /api/ekg_markers/:id
  def show
    render json: {
      success: true,
      data: {
        marker: marker_data(@marker)
      }
    }, status: :ok
  end
  
  # POST /api/recordings/:recording_id/markers
  def create
    marker_params = params.require(:marker).permit(
      :marker_type,
      :batch_sequence,
      :sample_index_start,
      :sample_index_end,
      :timestamp_start,
      :timestamp_end,
      :label,
      :description,
      :severity,
      metadata: {}
    )
    
    @marker = @recording.ekg_markers.new(marker_params)
    @marker.created_by = @current_user || User.first # TODO: Use authenticated user
    
    if @marker.save
      render json: {
        success: true,
        message: 'Marker berhasil ditambahkan',
        data: {
          marker: marker_data(@marker)
        }
      }, status: :created
    else
      render json: {
        success: false,
        message: 'Gagal menambahkan marker',
        errors: @marker.errors.full_messages
      }, status: :unprocessable_entity
    end
  end
  
  # PATCH/PUT /api/ekg_markers/:id
  def update
    marker_params = params.require(:marker).permit(
      :marker_type,
      :label,
      :description,
      :severity,
      metadata: {}
    )
    
    if @marker.update(marker_params)
      render json: {
        success: true,
        message: 'Marker berhasil diupdate',
        data: {
          marker: marker_data(@marker)
        }
      }, status: :ok
    else
      render json: {
        success: false,
        message: 'Gagal mengupdate marker',
        errors: @marker.errors.full_messages
      }, status: :unprocessable_entity
    end
  end
  
  # DELETE /api/ekg_markers/:id
  def destroy
    if @marker.destroy
      render json: {
        success: true,
        message: 'Marker berhasil dihapus'
      }, status: :ok
    else
      render json: {
        success: false,
        message: 'Gagal menghapus marker'
      }, status: :unprocessable_entity
    end
  end
  
  # GET /api/recordings/:recording_id/markers/summary
  def summary
    @recording = Recording.find(params[:recording_id])
    @markers = @recording.ekg_markers
    
    summary_data = {
      total_markers: @markers.count,
      by_type: {
        normal: @markers.by_type('normal').count,
        arrhythmia: @markers.by_type('arrhythmia').count,
        artifact: @markers.by_type('artifact').count,
        annotation: @markers.by_type('annotation').count
      },
      by_severity: {
        low: @markers.by_severity('low').count,
        medium: @markers.by_severity('medium').count,
        high: @markers.by_severity('high').count,
        critical: @markers.by_severity('critical').count
      },
      high_priority_count: @markers.high_priority.count,
      critical_markers: @markers.critical.map { |m| marker_data(m) }
    }
    
    render json: {
      success: true,
      data: summary_data
    }, status: :ok
  end
  
  private
  
  def set_recording
    @recording = Recording.find(params[:recording_id])
  rescue ActiveRecord::RecordNotFound
    render json: {
      success: false,
      error: 'Recording tidak ditemukan'
    }, status: :not_found
  end
  
  def set_marker
    @marker = EkgMarker.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: {
      success: false,
      error: 'Marker tidak ditemukan'
    }, status: :not_found
  end
  
  def marker_data(marker)
    {
      id: marker.id,
      recording_id: marker.recording_id,
      marker_type: marker.marker_type,
      batch_sequence: marker.batch_sequence,
      sample_index_start: marker.sample_index_start,
      sample_index_end: marker.sample_index_end,
      global_sample_start: marker.global_sample_start,
      global_sample_end: marker.global_sample_end,
      sample_count: marker.sample_count,
      timestamp_start: marker.timestamp_start.iso8601(3),
      timestamp_end: marker.timestamp_end.iso8601(3),
      duration_ms: marker.duration_ms,
      label: marker.label,
      description: marker.description,
      severity: marker.severity,
      color: marker.color,
      metadata: marker.metadata,
      created_by: {
        id: marker.created_by.id,
        name: marker.created_by.name,
        role: marker.created_by.role
      },
      created_at: marker.created_at.iso8601(3),
      updated_at: marker.updated_at.iso8601(3)
    }
  end
end
