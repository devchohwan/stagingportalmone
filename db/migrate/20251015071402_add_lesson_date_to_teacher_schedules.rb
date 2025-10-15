class AddLessonDateToTeacherSchedules < ActiveRecord::Migration[8.0]
  def change
    add_column :teacher_schedules, :lesson_date, :date
  end
end
