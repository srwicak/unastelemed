class ChangeHospitalIdToNullableInUsers < ActiveRecord::Migration[8.1]
  def change
    change_column_null :users, :hospital_id, true
  end
end
