class AddPatientIdentifierToPatients < ActiveRecord::Migration[8.1]
  def change
    add_column :patients, :patient_identifier, :string
    add_index :patients, :patient_identifier, unique: true
  end
end
