class AddMedicalConditionsToPatients < ActiveRecord::Migration[8.1]
  def change
    add_column :patients, :medical_conditions, :text
  end
end
