class AddWeekNumberToLessonDeductions < ActiveRecord::Migration[8.0]
  def change
    add_column :lesson_deductions, :week_number, :integer
    add_column :lesson_deductions, :year_month, :string
    
    add_index :lesson_deductions, [:user_enrollment_id, :year_month, :week_number], name: 'index_lesson_deductions_on_enrollment_year_week'
  end
end
