class CreateUploadSessions < ActiveRecord::Migration[8.1]
  def change
    create_table :upload_sessions do |t|
      t.references :recording, null: false, foreign_key: true
      t.string :upload_id
      t.string :session_id
      t.string :file_name
      t.bigint :file_size
      t.integer :chunk_size
      t.integer :total_chunks
      t.json :chunks_received
      t.integer :chunks_received_count
      t.string :file_sha256
      t.string :status

      t.timestamps
    end
    add_index :upload_sessions, :upload_id, unique: true
  end
end
