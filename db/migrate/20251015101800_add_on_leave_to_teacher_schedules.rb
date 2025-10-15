class AddOnLeaveToTeacherSchedules < ActiveRecord::Migration[8.0]
  def change
    add_column :teacher_schedules, :is_on_leave, :boolean, default: false, null: false
    add_reference :teacher_schedules, :user_enrollment, foreign_key: true
  end
end
