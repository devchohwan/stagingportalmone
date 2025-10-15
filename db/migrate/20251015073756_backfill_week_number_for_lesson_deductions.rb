class BackfillWeekNumberForLessonDeductions < ActiveRecord::Migration[8.0]
  def up
    LessonDeduction.where(week_number: nil).find_each do |deduction|
      week_number = ((deduction.deduction_date - deduction.deduction_date.beginning_of_month).to_i / 7) + 1
      year_month = deduction.deduction_date.strftime('%Y-%m')
      
      deduction.update_columns(
        week_number: week_number,
        year_month: year_month
      )
    end
  end

  def down
    LessonDeduction.update_all(week_number: nil, year_month: nil)
  end
end
