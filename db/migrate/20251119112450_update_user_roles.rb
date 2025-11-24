class UpdateUserRoles < ActiveRecord::Migration[8.1]
  def change
    # This migration updates the allowed roles for users
    # New roles: superuser, hospital_manager, doctor, nurse, patient
    # No actual schema change needed, just validation update in model
  end
end
