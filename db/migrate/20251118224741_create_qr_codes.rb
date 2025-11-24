class CreateQrCodes < ActiveRecord::Migration[8.1]
  def change
    create_table :qr_codes do |t|
      t.string :code
      t.references :hospital, null: false, foreign_key: true
      t.references :healthcare_provider, polymorphic: true, null: false
      t.datetime :valid_from
      t.datetime :valid_until
      t.integer :max_duration_minutes
      t.boolean :is_used
      t.datetime :expires_at
      t.references :patient, polymorphic: true, null: false

      t.timestamps
    end
    add_index :qr_codes, :code, unique: true
  end
end
