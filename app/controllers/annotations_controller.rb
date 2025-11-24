class AnnotationsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_recording
  
  def index
    @annotations = @recording.annotations.includes(:created_by).order(start_time: :asc)
    render json: @annotations.as_json(
      include: { created_by: { only: [:id, :name] } },
      methods: [:marker_type, :duration_seconds]
    )
  end

  def create
    @annotation = @recording.annotations.build(annotation_params)
    @annotation.created_by = current_user
    
    # Convert detik dari recording start ke timestamp
    if params[:annotation][:start_time_seconds]
      recording_start = @recording.start_time || @recording.created_at
      @annotation.start_time = recording_start + params[:annotation][:start_time_seconds].to_f.seconds
    end
    
    if params[:annotation][:end_time_seconds]
      recording_start = @recording.start_time || @recording.created_at
      @annotation.end_time = recording_start + params[:annotation][:end_time_seconds].to_f.seconds
    end
    
    if @annotation.save
      render json: @annotation.as_json(methods: [:marker_type, :duration_seconds]), status: :created
    else
      render json: { errors: @annotation.errors.full_messages }, status: :unprocessable_entity
    end
  end
  
  def destroy
    @annotation = @recording.annotations.find(params[:id])
    
    # Hanya pembuat atau medical staff yang bisa hapus
    unless @annotation.created_by == current_user || current_user.medical_staff
      return render json: { error: 'Access denied' }, status: :forbidden
    end
    
    @annotation.destroy
    render json: { message: 'Annotation deleted' }, status: :ok
  end

  private

  def set_recording
    @recording = Recording.find(params[:recording_id])
    
    # Check access
    unless can_access_recording?(@recording)
      render json: { error: 'Access denied' }, status: :forbidden
    end
  end

  def annotation_params
    params.require(:annotation).permit(:start_time, :end_time, :label, :notes, :start_time_seconds, :end_time_seconds)
  end

  def can_access_recording?(recording)
    return true if current_user.medical_staff
    return true if current_user.patient && recording.patient == current_user.patient
    false
  end
end
