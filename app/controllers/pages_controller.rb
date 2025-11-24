class PagesController < ApplicationController
  skip_before_action :authenticate_user!, only: [:landing, :hospital_portal]


  def landing
    redirect_to dashboard_path if current_user
  end
  
  def hospital_portal
    redirect_to dashboard_path if current_user
  end
end
