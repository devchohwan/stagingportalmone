class AddFirstLessonDateToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :first_lesson_date, :date
  end
end
