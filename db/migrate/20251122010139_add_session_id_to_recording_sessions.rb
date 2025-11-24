class AddSessionIdToRecordingSessions < ActiveRecord::Migration[8.1]
  def change
    add_column :recording_sessions, :session_id, :string
    add_index :recording_sessions, :session_id, unique: true
  end
end
