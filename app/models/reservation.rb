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
end