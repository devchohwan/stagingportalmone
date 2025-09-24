class Room < ApplicationRecord
  has_many :reservations
  
  validates :name, presence: true, uniqueness: true
  validates :number, presence: true, uniqueness: true
  
  def available_at?(start_time, end_time, exclude_reservation_id = nil)
    query = reservations
      .where(status: 'active')
      .where('(start_time < ? AND end_time > ?) OR (start_time < ? AND end_time > ?)', 
             end_time, start_time, end_time, start_time)
    
    query = query.where.not(id: exclude_reservation_id) if exclude_reservation_id
    
    !query.exists?
  end
end