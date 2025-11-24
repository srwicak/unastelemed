class AddNotesToRecordingSessions < ActiveRecord::Migration[8.1]
  def change
    add_column :recording_sessions, :notes, :text
  end
end
