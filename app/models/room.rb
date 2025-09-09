class Room < ApplicationRecord
  has_many :reservations
  
  validates :name, presence: true, uniqueness: true
  validates :number, presence: true, uniqueness: true
  
  def available_at?(start_time, end_time)
    !reservations
      .where(status: 'active')
      .where('(start_time < ? AND end_time > ?) OR (start_time < ? AND end_time > ?)', 
             end_time, start_time, end_time, start_time)
      .exists?
  end
end