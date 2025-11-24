class AddRecordingSessionIdToQrCodes < ActiveRecord::Migration[8.1]
  def change
    add_reference :qr_codes, :recording_session, null: true, foreign_key: true
  end
end
