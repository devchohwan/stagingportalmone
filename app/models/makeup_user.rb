class MakeupUser < MakeupBase
  self.table_name = 'users'
  
  has_many :reservations, class_name: 'Reservation', foreign_key: 'user_id'
  has_many :penalties, class_name: 'Penalty', foreign_key: 'user_id'
  
  # 승인된 사용자 스코프
  scope :approved, -> { where(status: 'approved') }
  
  # 현재 달의 페널티 정보 가져오기
  def current_month_penalty
    current_month = Date.current.month
    current_year = Date.current.year
    
    penalties.find_or_create_by(month: current_month, year: current_year) do |penalty|
      penalty.no_show_count = 0
      penalty.cancel_count = 0
      penalty.is_blocked = false
    end
  end
end