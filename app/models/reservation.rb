class Reservation < ApplicationRecord
  belongs_to :user
  belongs_to :room
  
  STATUSES = %w[active in_use completed cancelled no_show].freeze
  
  validates :start_time, presence: true
  validates :end_time, presence: true
  validates :status, inclusion: { in: STATUSES }
  validate :no_time_overlap, on: :create
  validate :valid_time_range
  validate :user_not_blocked, on: :create
  validate :no_duplicate_active_reservation, on: :create
  validate :one_reservation_per_day, on: :create
  
  scope :active, -> { where(status: ['active', 'in_use']) }
  scope :future, -> { where('start_time > ?', Time.current) }
  scope :past, -> { where('end_time < ?', Time.current) }
  scope :today, -> { where(start_time: Date.current.beginning_of_day..Date.current.end_of_day) }
  
  # 상태 변경 시 페널티 처리
  after_update :handle_status_change
  
  # 데이터베이스에서 시간을 옭을 때는 기본 ActiveRecord 메서드 사용
  # Rails가 자동으로 한국 시간대로 변환해줌
  
  def status_display
    # 실시간으로 현재 시간과 비교해서 표시
    if status == 'active' || status == 'in_use'
      current_time = Time.current.in_time_zone('Asia/Seoul')
      reservation_start = start_time
      reservation_end = end_time
      
      if current_time < reservation_start
        '이용 전'
      elsif current_time >= reservation_start && current_time < reservation_end
        '이용 중'
      elsif current_time >= reservation_end
        '완료'
      else
        status
      end
    else
      case status
      when 'completed' then '완료'
      when 'cancelled' then '취소'
      when 'no_show' then '노쇼'
      else status
      end
    end
  end
  
  # 현재 시간에 따라 상태 자동 업데이트
  def update_status_by_time!
    return unless status == 'active' || status == 'in_use'
    
    current_time = Time.current.in_time_zone('Asia/Seoul')
    reservation_start = start_time
    reservation_end = end_time
    
    if status == 'active' && current_time >= reservation_start && current_time < reservation_end
      # 이용 전 -> 이용 중
      update_column(:status, 'in_use')
    elsif (status == 'active' || status == 'in_use') && current_time >= reservation_end
      # 이용 중 -> 완료
      update_column(:status, 'completed')
    end
  end
  
  def cancellable?
    return false unless status == 'active'
    
    current_time = Time.current.in_time_zone('Asia/Seoul')
    reservation_start = start_time
    
    # 30분 전까지만 취소 가능
    current_time < (reservation_start - 30.minutes)
  end
  
  def changeable?
    return false unless status == 'active'
    
    current_time = Time.current.in_time_zone('Asia/Seoul')
    reservation_start = start_time
    
    # 1시간 전까지만 시간 변경 가능
    current_time < (reservation_start - 1.hour)
  end
  
  private
  
  def no_time_overlap
    return unless room && start_time && end_time
    
    overlapping = room.reservations
      .where(status: 'active')
      .where.not(id: id)
      .where('(start_time < ? AND end_time > ?) OR (start_time < ? AND end_time > ?)', 
             end_time, start_time, end_time, start_time)
    
    if overlapping.exists?
      errors.add(:base, '해당 시간대에 이미 예약이 있습니다')
    end
  end
  
  def valid_time_range
    return unless start_time && end_time
    
    if end_time <= start_time
      errors.add(:end_time, '종료 시간은 시작 시간보다 늦어야 합니다')
    end
    
    current_time = Time.current.in_time_zone('Asia/Seoul')
    if start_time <= current_time
      errors.add(:start_time, '과거 시간은 예약할 수 없습니다')
    end
    
  end
  
  def user_not_blocked
    return unless user
    
    if user.practice_penalty.is_blocked?
      errors.add(:base, '월 2회 이상 노쇼/취소로 연습실 이용이 제한되었습니다')
    end
  end
  
  def no_duplicate_active_reservation
    return unless user
    
    # active 상태의 미래 예약 확인
    existing = user.reservations
      .where(status: 'active')
      .where('start_time > ?', Time.current)
    existing = existing.where.not(id: id) if persisted?
    
    if existing.exists?
      errors.add(:base, '이미 활성 예약이 있습니다. 하나의 예약만 가능합니다.')
    end
  end
  
  def one_reservation_per_day
    return unless user && start_time
    
    # 요청된 날짜의 다른 예약 확인
    reservation_date = start_time.to_date
    existing = user.reservations
      .where('DATE(start_time) = ?', reservation_date)
      .where(status: ['active', 'completed'])
    existing = existing.where.not(id: id) if persisted?
    
    if existing.exists?
      errors.add(:base, '하루에 1회만 예약 가능합니다.')
    end
  end
  
  def handle_status_change
    return unless saved_change_to_status?
    
    penalty = user.practice_penalty  # 연습실 전용 페널티 사용
    old_status = saved_change_to_status[0]
    new_status = saved_change_to_status[1]
    
    case new_status
    when 'cancelled'
      # cancelled_by가 admin이면 페널티 부과 안함
      unless cancelled_by == 'admin'
        penalty.increment!(:cancel_count)
        penalty.reload  # 데이터베이스에서 최신 값 다시 로드
        Rails.logger.info "User #{user.id} practice penalty: cancel_count increased to #{penalty.cancel_count}"
      end
    when 'no_show'
      penalty.increment!(:no_show_count)
      penalty.reload  # 데이터베이스에서 최신 값 다시 로드
      Rails.logger.info "User #{user.id} practice penalty: no_show_count increased to #{penalty.no_show_count}"
    end
    
    # 총 2회 이상이면 차단 (연습실 시스템만)
    total_violations = penalty.cancel_count + penalty.no_show_count
    if total_violations >= 2 && !penalty.is_blocked
      penalty.update!(is_blocked: true)
      Rails.logger.info "User #{user.id} blocked from practice system due to #{total_violations} violations"
    end
  end
end