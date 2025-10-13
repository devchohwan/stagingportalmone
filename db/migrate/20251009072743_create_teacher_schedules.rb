class CreateTeacherSchedules < ActiveRecord::Migration[8.0]
  def change
    create_table :teacher_schedules do |t|
      t.string :teacher, null: false
      t.string :day, null: false
      t.string :time_slot, null: false
      t.integer :user_id, null: false

      t.timestamps
    end

    add_index :teacher_schedules, [:teacher, :day, :time_slot, :user_id], unique: true, name: 'index_teacher_schedules_unique'
    add_index :teacher_schedules, :user_id
  end
end
