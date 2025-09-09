class CreateMakeupTables < ActiveRecord::Migration[8.0]
  def up
    # 1. Create makeup_rooms table with same structure as rooms
    unless table_exists?(:makeup_rooms)
      create_table :makeup_rooms do |t|
      t.string :name
      t.integer :capacity
      t.text :description
      t.integer :number
      t.boolean :has_outlet
      t.timestamps
    end
    
      add_index :makeup_rooms, :number, unique: true
    end
    
    # 2. Create makeup_reservations table with makeup_room_id instead of room_id
    unless table_exists?(:makeup_reservations)
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
    end
    
    # 3. Copy data from rooms where number IN (1,2) to makeup_rooms (skip if already exists)
    if table_exists?(:rooms) && ActiveRecord::Base.connection.execute("SELECT COUNT(*) FROM makeup_rooms").first['count'].to_i == 0
      execute <<-SQL
        INSERT INTO makeup_rooms (id, name, capacity, description, number, has_outlet, created_at, updated_at)
        SELECT id, name, capacity, description, number, has_outlet, created_at, updated_at
        FROM rooms
        WHERE number IN (1, 2);
      SQL
    end
    
    # 4. Copy data from reservations where room_id IN (11,12) to makeup_reservations
    if table_exists?(:reservations) && ActiveRecord::Base.connection.execute("SELECT COUNT(*) FROM makeup_reservations").first['count'].to_i == 0
      execute <<-SQL
        INSERT INTO makeup_reservations (user_id, makeup_room_id, start_time, end_time, status, cancelled_by, created_at, updated_at)
        SELECT user_id, room_id, start_time, end_time, status, cancelled_by, created_at, updated_at
        FROM reservations
        WHERE room_id IN (11, 12);
      SQL
    end
    
    # 5. Add foreign key constraint if not exists
    unless foreign_key_exists?(:makeup_reservations, :makeup_rooms, column: :makeup_room_id)
      add_foreign_key :makeup_reservations, :makeup_rooms, column: :makeup_room_id
    end
  end
  
  def down
    drop_table :makeup_reservations
    drop_table :makeup_rooms
  end
end