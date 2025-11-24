class CreateHospitalAffiliations < ActiveRecord::Migration[8.1]
  def change
    create_table :hospital_affiliations do |t|
      t.references :medical_staff, null: false, foreign_key: true
      t.references :hospital, null: false, foreign_key: true
      t.string :status
      t.boolean :active
      t.datetime :started_at
      t.datetime :ended_at

      t.timestamps
    end
  end
end
