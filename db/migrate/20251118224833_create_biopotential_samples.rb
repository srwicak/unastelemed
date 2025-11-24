class CreateBiopotentialSamples < ActiveRecord::Migration[8.1]
  def change
    create_table :biopotential_samples do |t|
      t.references :recording, null: false, foreign_key: true
      t.datetime :timestamp
      t.integer :sample_value
      t.bigint :sequence_number

      t.timestamps
    end
  end
end
