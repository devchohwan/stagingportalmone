class AddAbsenceToTeacherSchedules < ActiveRecord::Migration[8.0]
  def change
    add_column :teacher_schedules, :is_absent, :boolean, default: false, null: false
  end
end
