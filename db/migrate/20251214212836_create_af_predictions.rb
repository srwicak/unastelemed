# frozen_string_literal: true

class CreateAfPredictions < ActiveRecord::Migration[8.1]
  def change
    create_table :af_predictions do |t|
      t.references :recording, null: false, foreign_key: true
      t.references :predicted_by, null: true, foreign_key: { to_table: :users }
      t.boolean :af_detected, default: false
      t.integer :af_event_count, default: 0
      t.decimal :af_burden_percent, precision: 5, scale: 2
      t.decimal :total_analyzed_minutes, precision: 10, scale: 2
      t.decimal :normal_rhythm_minutes, precision: 10, scale: 2
      t.decimal :af_minutes, precision: 10, scale: 2
      t.decimal :hr_min_bpm, precision: 5, scale: 1
      t.decimal :hr_avg_bpm, precision: 5, scale: 1
      t.decimal :hr_max_bpm, precision: 5, scale: 1
      t.jsonb :af_events, default: []
      t.jsonb :summary, default: {}
      t.jsonb :hrv_metrics, default: {}
      t.text :conclusion
      t.jsonb :window_probabilities, default: []
      t.string :status, default: 'completed'
      t.datetime :predicted_at

      t.timestamps
    end

    add_index :af_predictions, :recording_id
    add_index :af_predictions, :predicted_at
    add_index :af_predictions, :af_detected
  end
end
