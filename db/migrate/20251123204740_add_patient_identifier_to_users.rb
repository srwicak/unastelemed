class AddPatientIdentifierToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :patient_identifier, :string, limit: 12
    add_index :users, :patient_identifier, unique: true
    
    # Generate patient_identifier untuk semua existing users
    reversible do |dir|
      dir.up do
        require 'nanoid'
        User.find_each do |user|
          loop do
            candidate = Nanoid.generate(size: 12)
            begin
              user.update_column(:patient_identifier, candidate)
              break
            rescue ActiveRecord::RecordNotUnique
              # Try again with different ID
              next
            end
          end
        end
      end
    end
  end
end
