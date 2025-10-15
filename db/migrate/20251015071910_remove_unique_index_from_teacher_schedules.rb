class RemoveUniqueIndexFromTeacherSchedules < ActiveRecord::Migration[8.0]
  def change
    remove_index :teacher_schedules, [:teacher, :day, :time_slot, :user_id], if_exists: true
    add_index :teacher_schedules, [:lesson_date, :user_id], unique: true
  end
end
