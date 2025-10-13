class AddFirstLessonTimeToPayments < ActiveRecord::Migration[8.0]
  def change
    add_column :payments, :first_lesson_time, :string
  end
end
