class AddCancellationReasonToMakeupReservations < ActiveRecord::Migration[8.0]
  def change
    add_column :makeup_reservations, :cancellation_reason, :text
  end
end
