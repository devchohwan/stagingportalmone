class MakeupRoom < MakeupBase
  self.table_name = 'makeup_rooms'
  
  has_many :reservations, class_name: 'MakeupReservation', foreign_key: 'makeup_room_id'
end
