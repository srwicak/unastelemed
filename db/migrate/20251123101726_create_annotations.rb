class CreateAnnotations < ActiveRecord::Migration[8.1]
  def change
    create_table :annotations do |t|
      t.references :recording, null: false, foreign_key: true
      t.datetime :start_time
      t.datetime :end_time
      t.string :label
      t.text :notes
      t.references :created_by, null: false, foreign_key: { to_table: :users }

      t.timestamps
    end
  end
end
