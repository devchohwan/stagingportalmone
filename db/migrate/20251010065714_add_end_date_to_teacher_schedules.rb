class AddEndDateToTeacherSchedules < ActiveRecord::Migration[8.0]
  def change
    add_column :teacher_schedules, :end_date, :date
  end
end
