(4..8).each do |i|
  MakeupRoom.create!(
    number: i,
    name: "보충수업실 #{i}",
    has_outlet: [2, 4, 7, 8].include?(i)
  )
end
puts 'Created additional rooms'
MakeupRoom.all.each do |r|
  puts "Room #{r.number}: outlet=#{r.has_outlet}"
end