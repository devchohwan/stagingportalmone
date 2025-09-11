class MakeupReservation < MakeupBase
  self.table_name = 'makeup_reservations'
  
  # 관계 설정
  belongs_to :user, foreign_key: 'user_id'
  belongs_to :makeup_room, foreign_key: 'makeup_room_id'
  
  # 별지
  alias_method :room, :makeup_room
  
  # 검증
  validate :no_same_day_reservation
  
  private
  
  def no_same_day_reservation
    return unless start_time.present?
    
    if start_time.to_date == Date.current
      errors.add(:start_time, '당일 예약은 불가능합니다')
    end
  end
  
  public
  
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
  
  STATUSES = %w[pending active completed cancelled rejected no_show].freeze
  
  def status_display
    case status
    when 'pending' then '승인 대기'
    when 'active' then '수업 대기'
    when 'cancelled' then '취소됨'
    when 'rejected' then '거절됨'
    when 'completed' then '완료'
    when 'no_show' then '노쇼'
    else status
    end
  end
  
  def cancellable?
    (status == 'pending' || status == 'active') && start_time > 30.minutes.from_now
  end
  
  # 시간에 따른 상태 자동 업데이트 (연습실 로직과 동일)
  def update_status_by_time!
    return unless status == 'active'  # pending은 관리자 승인 필요하므로 제외
    
    current_time = Time.current.in_time_zone('Asia/Seoul')
    reservation_end = end_time
    
    # active 상태이고 종료 시간이 지났으면 completed로 변경
    if current_time >= reservation_end
      update_column(:status, 'completed')
    end
  end
end