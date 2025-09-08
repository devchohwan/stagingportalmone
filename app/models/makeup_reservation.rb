class MakeupReservation < MakeupBase
  self.table_name = 'reservations'
  
  # 관계 설정
  belongs_to :user, class_name: 'MakeupUser', foreign_key: 'user_id'
  belongs_to :room, class_name: 'MakeupRoom', foreign_key: 'room_id'
  
  # 스코프
  scope :active, -> { where(status: 'active') }
  scope :today, -> { 
    # UTC로 저장되어 있으므로 KST 기준으로 조회
    kst_start = (Date.current.beginning_of_day - 9.hours)
    kst_end = (Date.current.end_of_day - 9.hours)
    where(start_time: kst_start..kst_end) 
  }
  
  # 시간 속성을 KST로 변환
  def start_time
    time = super
    return nil unless time
    # UTC로 저장된 시간을 KST로 변환 (9시간 추가)
    time + 9.hours
  end
  
  def end_time
    time = super
    return nil unless time
    # UTC로 저장된 시간을 KST로 변환 (9시간 추가)
    time + 9.hours
  end
end