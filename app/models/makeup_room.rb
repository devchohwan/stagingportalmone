class MakeupRoom < MakeupBase
  self.table_name = 'makeup_rooms'
  
  has_many :reservations, class_name: 'MakeupReservation', foreign_key: 'makeup_room_id'
  
  def available_at?(start_time, end_time)
    !reservations
      .where(status: 'active')
      .where('(start_time < ? AND end_time > ?) OR (start_time < ? AND end_time > ?)', 
             end_time, start_time, end_time, start_time)
      .exists?
  end
end
