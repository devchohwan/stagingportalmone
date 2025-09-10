# Test reservation status display
r = Reservation.create!(
  user_id: 1, 
  room_id: 1, 
  start_time: 2.hours.ago, 
  end_time: 1.hour.ago, 
  status: "active"
)

puts "Created reservation ID: #{r.id}"
puts "Status in DB: #{r.status}"
puts "Display shows: #{r.status_display}"
puts "Should show: 완료 (because time has passed)"

puts "\nCalling update_status_by_time!..."
r.update_status_by_time!
r.reload

puts "After update:"
puts "Status in DB: #{r.status}"
puts "Display shows: #{r.status_display}"