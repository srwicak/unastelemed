class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.string :email
      t.string :password_digest
      t.string :name
      t.string :phone
      t.string :role
      t.date :date_of_birth
      t.string :medical_record_number
      t.references :hospital, null: false, foreign_key: true

      t.timestamps
    end
    add_index :users, :email, unique: true
  end
end
