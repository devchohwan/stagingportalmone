class AddStartDateToTeacherSchedules < ActiveRecord::Migration[8.0]
  def change
    add_column :teacher_schedules, :start_date, :date unless column_exists?(:teacher_schedules, :start_date)
  end
end
