class AddApprovalFieldsToMedicalStaffs < ActiveRecord::Migration[8.1]
  def change
    add_column :medical_staffs, :approval_status, :string, default: 'pending'
    add_column :medical_staffs, :approved_by, :integer
    add_column :medical_staffs, :approved_at, :datetime
    add_index :medical_staffs, :approval_status
  end
end
