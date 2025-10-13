class AddFirstLessonDateToPayments < ActiveRecord::Migration[8.0]
  def change
    add_column :payments, :first_lesson_date, :date
  end
end
