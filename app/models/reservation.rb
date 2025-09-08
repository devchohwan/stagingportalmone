class Reservation < ApplicationRecord
  belongs_to :user
  belongs_to :room
  
  STATUSES = %w[active completed cancelled no_show].freeze
  
  validates :start_time, presence: true
  validates :end_time, presence: true
  validates :status, inclusion: { in: STATUSES }
  
  scope :active, -> { where(status: 'active') }
  scope :future, -> { where('start_time > ?', Time.current) }
  scope :past, -> { where('end_time < ?', Time.current) }
  scope :today, -> { where(start_time: Date.current.beginning_of_day..Date.current.end_of_day) }
  
  # 상태 변경 시 페널티 처리
  after_update :handle_status_change
  
  # 시간 속성을 KST로 변환
  def start_time
    time = super
    return nil unless time
    # UTC로 읽힌 시간을 KST로 변환 (9시간 추가)
    time + 9.hours
  end
  
  def end_time
    time = super
    return nil unless time
    # UTC로 읽힌 시간을 KST로 변환 (9시간 추가)
    time + 9.hours
  end
  
  def status_display
    return status unless status == 'active'
    
    current_time = Time.current
    
    if current_time < start_time
      '이용 전'
    elsif current_time >= start_time && current_time < end_time
      '이용 중'
    elsif current_time >= end_time
      '완료'
    else
      status
    end
  end
  
  private
  
  def handle_status_change
    return unless saved_change_to_status?
    
    penalty = user.current_month_penalty
    
    case status
    when 'cancelled'
      # cancelled_by가 admin이면 페널티 부과 안함
      unless cancelled_by == 'admin'
        penalty.increment!(:cancel_count)
      end
    when 'no_show'
      penalty.increment!(:no_show_count)
    end
    
    # 총 2회 이상이면 차단
    if penalty.cancel_count + penalty.no_show_count >= 2
      penalty.update!(is_blocked: true)
    end
  end
end