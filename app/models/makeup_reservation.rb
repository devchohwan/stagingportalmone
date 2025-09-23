class MakeupReservation < MakeupBase
  self.table_name = 'makeup_reservations'
  
  # 관계 설정
  belongs_to :user, foreign_key: 'user_id'
  belongs_to :makeup_room, foreign_key: 'makeup_room_id'
  
  # 별지
  alias_method :room, :makeup_room
  
  # 검증
  validate :no_same_day_reservation
  
  # 상태 변경 시 페널티 처리 (연습실과 동일한 로직)
  after_update :handle_status_change
  
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
    # Rails는 자동으로 시간대를 처리하므로 그냥 Date.current 사용
    where(start_time: Date.current.beginning_of_day..Date.current.end_of_day)
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
  
  # 클래스 메서드로 모든 레코드 업데이트
  def self.update_status_by_time!
    where(status: 'active').find_each(&:update_status_by_time!)
  end
  
  # 연습실과 동일한 페널티 처리 로직
  def handle_status_change
    return unless saved_change_to_status?
    
    penalty = user.makeup_penalty  # 보충수업 전용 페널티 사용
    old_status = saved_change_to_status[0]
    new_status = saved_change_to_status[1]
    
    case new_status
    when 'cancelled'
      # cancelled_by가 admin이면 페널티 부과 안함
      unless cancelled_by == 'admin'
        penalty.increment!(:cancel_count)
        penalty.reload  # 데이터베이스에서 최신 값 다시 로드
        Rails.logger.info "User #{user.id} makeup penalty: cancel_count increased to #{penalty.cancel_count}"
      end
    when 'no_show'
      penalty.increment!(:no_show_count)
      penalty.reload  # 데이터베이스에서 최신 값 다시 로드
      Rails.logger.info "User #{user.id} makeup penalty: no_show_count increased to #{penalty.no_show_count}"
    end
    
    # 총 2회 이상이면 차단 (보충수업 시스템만)
    total_violations = penalty.cancel_count + penalty.no_show_count
    if total_violations >= 2 && !penalty.is_blocked
      penalty.update!(is_blocked: true)
      Rails.logger.info "User #{user.id} blocked from makeup system due to #{total_violations} violations"
    end
  end
end