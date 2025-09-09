class CreateMakeupReservations < ActiveRecord::Migration[8.0]
  def change
    create_table :makeup_reservations do |t|
      t.references :user, null: false, foreign_key: true
      t.references :makeup_room, null: false, foreign_key: true
      t.datetime :start_time, null: false
      t.datetime :end_time, null: false
      t.string :status, default: 'active' # active, completed, cancelled, no_show
      t.string :cancelled_by # user, admin
      t.text :notes
      
      t.timestamps
    end
    
    add_index :makeup_reservations, :status
    add_index :makeup_reservations, [:user_id, :status]
    add_index :makeup_reservations, [:start_time, :end_time]
  end
end
