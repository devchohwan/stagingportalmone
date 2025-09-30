class CreatePitchReservations < ActiveRecord::Migration[8.0]
  def change
    create_table :pitch_reservations do |t|
      t.references :user, null: false, foreign_key: true
      t.references :pitch_room, null: false, foreign_key: true
      t.datetime :start_time, null: false
      t.datetime :end_time, null: false
      t.string :status, default: 'pending'
      t.datetime :approved_at
      t.string :approved_by
      t.string :cancelled_by
      t.datetime :cancelled_at
      t.text :cancellation_reason
      t.text :notes
      t.text :admin_note

      t.timestamps
    end

    add_index :pitch_reservations, [:pitch_room_id, :start_time]
    add_index :pitch_reservations, [:user_id, :start_time]
    add_index :pitch_reservations, [:user_id, :status]
    add_index :pitch_reservations, :status
    add_index :pitch_reservations, [:start_time, :end_time]
  end
end
