class CreateRecordings < ActiveRecord::Migration[8.1]
  def change
    create_table :recordings do |t|
      t.references :patient, null: false, foreign_key: true
      t.references :hospital, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :session_id
      t.datetime :start_time
      t.datetime :end_time
      t.integer :duration_seconds
      t.integer :total_samples
      t.decimal :sample_rate
      t.string :status
      t.string :csv_file_path
      t.text :notes
      t.text :interpretation

      t.timestamps
    end
    add_index :recordings, :session_id, unique: true
  end
end
