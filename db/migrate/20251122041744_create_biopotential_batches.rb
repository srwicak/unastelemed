class CreateBiopotentialBatches < ActiveRecord::Migration[8.1]
  def change
    create_table :biopotential_batches do |t|
      t.references :recording, null: false, foreign_key: true
      t.datetime :start_timestamp, null: false
      t.datetime :end_timestamp, null: false
      t.integer :batch_sequence, null: false
      t.decimal :sample_rate, precision: 10, scale: 2, null: false
      t.integer :sample_count, null: false
      t.jsonb :data, null: false, default: {}

      t.timestamps
    end
    
    # Add indexes for efficient querying
    add_index :biopotential_batches, [:recording_id, :batch_sequence], unique: true, name: 'index_batches_on_recording_and_sequence'
    add_index :biopotential_batches, [:recording_id, :start_timestamp], name: 'index_batches_on_recording_and_time'
    add_index :biopotential_batches, :data, using: :gin, name: 'index_batches_on_data'
  end
end
