class CreateMedicalStaffs < ActiveRecord::Migration[8.1]
  def change
    create_table :medical_staffs do |t|
      t.references :user, null: false, foreign_key: true
      t.references :hospital, null: false, foreign_key: true
      t.string :name
      t.string :role
      t.string :license_number
      t.string :specialization
      t.string :phone

      t.timestamps
    end
  end
end
