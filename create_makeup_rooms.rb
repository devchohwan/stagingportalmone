puts 'MakeupRoom count: ' + MakeupRoom.count.to_s
if MakeupRoom.count == 0
  puts 'Creating makeup rooms...'
  (1..8).each do |i|
    MakeupRoom.create!(
      number: i,
      name: "보충 #{i}번",
      has_outlet: [2, 4, 7, 8].include?(i)
    )
  end
  puts 'Created 8 makeup rooms'
end
MakeupRoom.all.each do |r|
  puts "Room #{r.number}: #{r.name} (outlet: #{r.has_outlet})"
end