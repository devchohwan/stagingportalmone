class AddCancellationReasonToReservations < ActiveRecord::Migration[8.0]
  def change
    add_column :reservations, :cancellation_reason, :text
  end
end
