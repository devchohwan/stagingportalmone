class AddWeekNumberToPitchReservations < ActiveRecord::Migration[8.0]
  def change
    add_column :pitch_reservations, :week_number, :integer
  end
end
