class FixTeacherSchedulesUniqueIndex < ActiveRecord::Migration[8.0]
  def change
    remove_index :teacher_schedules, [:lesson_date, :user_id], if_exists: true
    add_index :teacher_schedules, [:lesson_date, :user_id, :time_slot], unique: true, name: 'index_ts_on_date_user_time'
  end
end
