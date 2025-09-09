class MakeupReservation < MakeupBase
  self.table_name = 'makeup_reservations'
  
  # 관계 설정
  belongs_to :user, foreign_key: 'user_id'
  belongs_to :makeup_room, foreign_key: 'makeup_room_id'
  
  # 별지
  alias_method :room, :makeup_room
  
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
    # UTC로 저장된 시간을 KST로 변환
    time.in_time_zone('Asia/Seoul')
  end
  
  def end_time
    time = super
    return nil unless time
    # UTC로 저장된 시간을 KST로 변환
    time.in_time_zone('Asia/Seoul')
  end
  
  def status_display
    case status
    when 'pending' then '승인 대기'
    when 'active' then '활성'
    when 'cancelled' then '취소됨'
    when 'completed' then '완료'
    when 'no_show' then '노쇼'
    else status
    end
  end
  
  def cancellable?
    (status == 'pending' || status == 'active') && start_time > 30.minutes.from_now
  end
end