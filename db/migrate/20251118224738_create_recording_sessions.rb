class CreateRecordingSessions < ActiveRecord::Migration[8.1]
  def change
    create_table :recording_sessions do |t|
      t.references :patient, null: false, foreign_key: true
      t.references :medical_staff, null: false, foreign_key: true
      t.string :status
      t.datetime :started_at
      t.datetime :ended_at

      t.timestamps
    end
  end
end
