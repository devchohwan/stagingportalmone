class CreateLessonDeductions < ActiveRecord::Migration[8.0]
  def change
    create_table :lesson_deductions do |t|
      t.integer :user_enrollment_id, null: false
      t.date :deduction_date, null: false
      t.datetime :deduction_time, null: false

      t.timestamps
    end

    add_index :lesson_deductions, [:user_enrollment_id, :deduction_date], unique: true, name: 'index_lesson_deductions_on_enrollment_and_date'
  end
end
