class AddTeacherHistoryToUserEnrollments < ActiveRecord::Migration[8.0]
  def change
    add_column :user_enrollments, :teacher_history, :text
  end
end
