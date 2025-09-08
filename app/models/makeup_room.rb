class MakeupRoom < MakeupBase
  self.table_name = 'rooms'
  
  has_many :reservations, class_name: 'MakeupReservation', foreign_key: 'room_id'
end
