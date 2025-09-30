class CreatePitchRooms < ActiveRecord::Migration[8.0]
  def change
    create_table :pitch_rooms do |t|
      t.string :name, null: false
      t.integer :seat_number, null: false
      t.boolean :is_active, default: true

      t.timestamps
    end

    add_index :pitch_rooms, :seat_number, unique: true
    add_index :pitch_rooms, :is_active
  end
end
