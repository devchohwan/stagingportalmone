require 'sqlite3'

# Open the PT-monemusic database (which has the actual data)
practice_db_path = '/home/cho/pt-monemusic/storage/development.sqlite3'
unless File.exist?(practice_db_path)
  puts "PT database not found at #{practice_db_path}"
  exit
end

puts "Using PT-monemusic database: #{practice_db_path}"

practice_db = SQLite3::Database.new(practice_db_path)
practice_db.results_as_hash = true

# Import users
puts '=== Importing Users ==='
practice_users = practice_db.execute('SELECT * FROM users')
imported_users = 0
skipped_users = 0

practice_users.each do |user|
  existing = User.find_by(username: user['username'])
  if existing
    puts "Skipping duplicate user: #{user['username']}"
    skipped_users += 1
  else
    User.create!(
      username: user['username'],
      name: user['name'] || user['username'],
      email: user['email'],
      phone: user['phone'],
      teacher: user['teacher'],
      password_digest: user['password_digest'],
      status: user['status'] || 'approved',
      is_admin: user['is_admin'] == 1
    )
    puts "Imported user: #{user['username']}"
    imported_users += 1
  end
end

# Import rooms
puts '=== Importing Rooms ==='
practice_rooms = practice_db.execute('SELECT * FROM rooms')
practice_rooms.each do |room|
  Room.find_or_create_by(number: room['number']) do |r|
    r.has_outlet = room['has_outlet'] == 1
  end
  puts "Imported room: #{room['number']}"
end

# Import reservations
puts '=== Importing Reservations ==='
practice_reservations = practice_db.execute('SELECT * FROM reservations')
imported_reservations = 0

practice_reservations.each do |res|
  # Map user IDs from PT database to portal database
  pt_user = practice_db.execute("SELECT username FROM users WHERE id = ?", res['user_id']).first
  if pt_user
    user = User.find_by(username: pt_user['username'])
    room = Room.find_by(number: res['room_id'])  # Use room number instead of ID
    
    if user && room
      # Skip validation for historical data import
      reservation = Reservation.new(
        user_id: user.id,
        room_id: room.id,
        start_time: res['start_time'],
        end_time: res['end_time'],
        status: res['status'] || 'completed',  # Mark old reservations as completed
        created_at: res['created_at'] || Time.current,
        updated_at: res['updated_at'] || Time.current
      )
      reservation.save!(validate: false)  # Skip validations for historical data
      imported_reservations += 1
      puts "Imported reservation for user #{user.username}"
    end
  end
end

# Import penalties
puts '=== Importing Penalties ==='
practice_penalties = practice_db.execute('SELECT * FROM penalties')
imported_penalties = 0

practice_penalties.each do |penalty|
  # Map user IDs from PT database to portal database
  pt_user = practice_db.execute("SELECT username FROM users WHERE id = ?", penalty['user_id']).first
  if pt_user
    user = User.find_by(username: pt_user['username'])
    if user
      existing = Penalty.find_by(user_id: user.id, month: penalty['month'])
      if existing
        existing.update!(
          no_show_count: penalty['no_show_count'] || 0,
          cancel_count: penalty['cancel_count'] || 0,
          is_blocked: penalty['is_blocked'] == 1
        )
      else
        Penalty.create!(
          user_id: user.id,
          month: penalty['month'],
          no_show_count: penalty['no_show_count'] || 0,
          cancel_count: penalty['cancel_count'] || 0,
          is_blocked: penalty['is_blocked'] == 1
        )
      end
      imported_penalties += 1
      puts "Imported penalty for user #{user.username}"
    end
  end
end

practice_db.close

puts '=== Import Summary ==='
puts "Users: #{imported_users} imported, #{skipped_users} skipped"
puts "Rooms: #{Room.count} total"
puts "Reservations: #{imported_reservations} imported"
puts "Penalties: #{imported_penalties} imported"
puts "Total users in system: #{User.count}"
puts "Total reservations in system: #{Reservation.count}"