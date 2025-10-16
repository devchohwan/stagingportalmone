class AddTotalLessonsToUserEnrollments < ActiveRecord::Migration[8.0]
  def change
    add_column :user_enrollments, :total_lessons, :integer, default: 0, null: false
    
    reversible do |dir|
      dir.up do
        UserEnrollment.find_each do |enrollment|
          deductions_count = enrollment.lesson_deductions.count
          total = enrollment.remaining_lessons + deductions_count
          enrollment.update_column(:total_lessons, total)
        end
      end
    end
  end
end
