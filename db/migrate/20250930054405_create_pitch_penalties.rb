class CreatePitchPenalties < ActiveRecord::Migration[8.0]
  def change
    create_table :pitch_penalties do |t|
      t.references :user, null: false, foreign_key: true
      t.integer :penalty_count, default: 0, null: false
      t.integer :month, null: false
      t.integer :year, null: false
      t.boolean :is_blocked, default: false, null: false

      t.timestamps
    end

    add_index :pitch_penalties, [:user_id, :month, :year], unique: true
  end
end
