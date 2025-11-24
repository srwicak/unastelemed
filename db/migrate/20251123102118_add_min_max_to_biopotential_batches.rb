class AddMinMaxToBiopotentialBatches < ActiveRecord::Migration[8.1]
  def change
    add_column :biopotential_batches, :min_value, :float
    add_column :biopotential_batches, :max_value, :float
  end
end
