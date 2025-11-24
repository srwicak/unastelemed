class CreatePatients < ActiveRecord::Migration[8.1]
  def change
    create_table :patients do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name
      t.date :date_of_birth
      t.string :gender
      t.string :phone_number
      t.text :address
      t.string :emergency_contact
      t.string :medical_record_number
      t.string :blood_type
      t.text :allergies

      t.timestamps
    end
  end
end
