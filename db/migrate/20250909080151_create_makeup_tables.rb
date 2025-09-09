class CreateMakeupTables < ActiveRecord::Migration[8.0]
  def up
    # 1. Create makeup_rooms table with same structure as rooms
    create_table :makeup_rooms do |t|
      t.string :name
      t.integer :capacity
      t.text :description
      t.integer :number
      t.boolean :has_outlet
      t.timestamps
    end
    
    add_index :makeup_rooms, :number, unique: true
    
    # 2. Create makeup_reservations table with makeup_room_id instead of room_id
    create_table :makeup_reservations do |t|
      t.references :user, foreign_key: true
      t.integer :makeup_room_id
      t.datetime :start_time
      t.datetime :end_time
      t.string :status, default: 'pending'
      t.string :cancelled_by
      t.timestamps
    end
    
    add_index :makeup_reservations, :makeup_room_id
    add_index :makeup_reservations, :status
    add_index :makeup_reservations, :start_time
    add_index :makeup_reservations, :end_time
    
    # 3. Copy data from rooms where number IN (1,2) to makeup_rooms
    execute <<-SQL
      INSERT INTO makeup_rooms (id, name, capacity, description, number, has_outlet, created_at, updated_at)
      SELECT id, name, capacity, description, number, has_outlet, created_at, updated_at
      FROM rooms
      WHERE number IN (1, 2);
    SQL
    
    # 4. Copy data from reservations where room_id IN (11,12) to makeup_reservations
    execute <<-SQL
      INSERT INTO makeup_reservations (user_id, makeup_room_id, start_time, end_time, status, cancelled_by, created_at, updated_at)
      SELECT user_id, room_id, start_time, end_time, status, cancelled_by, created_at, updated_at
      FROM reservations
      WHERE room_id IN (11, 12);
    SQL
    
    # 5. Add foreign key constraint
    add_foreign_key :makeup_reservations, :makeup_rooms, column: :makeup_room_id
  end
  
  def down
    drop_table :makeup_reservations
    drop_table :makeup_rooms
  end
end