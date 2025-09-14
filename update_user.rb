user = User.find_by(username: 'starhyjung')
if user
  puts "Found: #{user.name} (#{user.username})"
  puts "Current status: #{user.status}"
  user.status = 'pending'
  if user.save
    puts "Successfully updated to pending"
  else
    puts "Failed to update: #{user.errors.full_messages.join(', ')}"
  end
else
  puts "User 'starhyjung' not found"
  users = User.where("name LIKE ?", "%정혜연%")
  if users.any?
    puts "Found users with name containing '정혜연':"
    users.each do |u|
      puts "  #{u.name} (#{u.username}) - Status: #{u.status}"
    end
  end
end