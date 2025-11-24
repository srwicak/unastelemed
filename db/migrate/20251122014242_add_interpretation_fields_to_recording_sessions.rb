class AddInterpretationFieldsToRecordingSessions < ActiveRecord::Migration[8.1]
  def change
    add_column :recording_sessions, :doctor_notes, :text
    add_column :recording_sessions, :diagnosis, :string
    add_column :recording_sessions, :recommendations, :text
    add_column :recording_sessions, :interpretation_completed, :boolean, default: false, null: false
  end
end
