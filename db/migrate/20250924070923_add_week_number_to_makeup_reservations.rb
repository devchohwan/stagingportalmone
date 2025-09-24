class AddWeekNumberToMakeupReservations < ActiveRecord::Migration[8.0]
  def change
    add_column :makeup_reservations, :week_number, :integer
  end
end
