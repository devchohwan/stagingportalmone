# Test with existing reservation
r = Reservation.where(status: 'active').first
if r
  puts "Found reservation ID: #{r.id}"
  puts "Status in DB: #{r.status}"
  puts "Start: #{r.start_time}"
  puts "End: #{r.end_time}"
  puts "Current: #{Time.current}"
  puts "Display shows: #{r.status_display}"
  
  puts "\nCalling update_status_by_time!..."
  r.update_status_by_time!
  r.reload
  
  puts "After update:"
  puts "Status in DB: #{r.status}"
  puts "Display shows: #{r.status_display}"
else
  puts "No active reservations found"
end