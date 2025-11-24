class AddDoctorReviewFieldsToRecordings < ActiveRecord::Migration[8.1]
  def change
    add_column :recordings, :reviewed_by_doctor, :boolean, default: false
    add_column :recordings, :doctor_id, :bigint
    add_column :recordings, :reviewed_at, :datetime
    add_column :recordings, :has_notes, :boolean, default: false
    add_column :recordings, :doctor_notes, :text
    add_column :recordings, :diagnosis, :string
    
    # Add indexes for performance
    add_index :recordings, :reviewed_by_doctor
    add_index :recordings, :doctor_id
    add_index :recordings, [:patient_id, :reviewed_by_doctor]
    
    # Add foreign key to users table (doctor_id references User.id)
    add_foreign_key :recordings, :users, column: :doctor_id
  end
end
