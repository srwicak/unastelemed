class AddUsedAtToQrCodes < ActiveRecord::Migration[8.1]
  def change
    add_column :qr_codes, :used_at, :datetime
  end
end
