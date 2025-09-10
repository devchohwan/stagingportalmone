class AddLessonContentToMakeupReservations < ActiveRecord::Migration[8.0]
  def change
    add_column :makeup_reservations, :lesson_content, :text
  end
end
