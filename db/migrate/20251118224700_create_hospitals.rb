class CreateHospitals < ActiveRecord::Migration[8.1]
  def change
    create_table :hospitals do |t|
      t.string :name
      t.text :address
      t.string :phone
      t.string :email
      t.string :code

      t.timestamps
    end
    add_index :hospitals, :code, unique: true
  end
end
