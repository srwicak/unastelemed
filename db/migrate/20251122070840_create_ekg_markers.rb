class CreateEkgMarkers < ActiveRecord::Migration[8.1]
  def change
    create_table :ekg_markers do |t|
      t.references :recording, null: false, foreign_key: true
      t.references :created_by, null: false, foreign_key: { to_table: :users }
      t.string :marker_type, null: false
      t.integer :batch_sequence, null: false
      t.integer :sample_index_start, null: false
      t.integer :sample_index_end, null: false
      t.datetime :timestamp_start, null: false
      t.datetime :timestamp_end, null: false
      t.string :label
      t.text :description
      t.string :severity, default: 'low'
      t.jsonb :metadata, default: {}

      t.timestamps
    end
    
    # Add indexes for efficient querying
    add_index :ekg_markers, [:recording_id, :batch_sequence], name: 'index_ekg_markers_on_recording_and_batch'
    add_index :ekg_markers, [:recording_id, :marker_type], name: 'index_ekg_markers_on_recording_and_type'
    add_index :ekg_markers, :severity
  end
end
