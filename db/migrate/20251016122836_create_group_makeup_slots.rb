class CreateGroupMakeupSlots < ActiveRecord::Migration[8.0]
  def change
    create_table :group_makeup_slots do |t|
      t.string :teacher, null: false
      t.string :subject, null: false
      t.integer :week_number, null: false
      t.date :lesson_date, null: false
      t.string :day, null: false
      t.string :time_slot, null: false
      t.integer :max_capacity, default: 3, null: false
      t.string :status, default: 'active', null: false

      t.timestamps
    end

    add_index :group_makeup_slots, [:lesson_date, :teacher, :time_slot]
    add_index :group_makeup_slots, [:subject, :week_number, :lesson_date]
  end
end
