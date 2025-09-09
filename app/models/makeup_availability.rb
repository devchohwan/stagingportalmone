class MakeupAvailability < ApplicationRecord
  DAYS_OF_WEEK = {
    0 => '일요일',
    1 => '월요일', 
    2 => '화요일',
    3 => '수요일',
    4 => '목요일',
    5 => '금요일',
    6 => '토요일'
  }.freeze
  
  validates :teacher_name, presence: true
  validates :day_of_week, inclusion: { in: 0..6 }, allow_nil: true
  validates :start_time, presence: true
  validates :end_time, presence: true
  validate :valid_time_range
  
  scope :active, -> { where(is_active: true) }
  scope :for_teacher, ->(name) { where(teacher_name: name) }
  scope :for_day, ->(day) { where(day_of_week: day) }
  
  def day_name
    DAYS_OF_WEEK[day_of_week]
  end
  
  def time_range_display
    "#{start_time.strftime('%H:%M')} - #{end_time.strftime('%H:%M')}"
  end
  
  def available_on?(datetime)
    return false unless is_active
    return true if day_of_week.nil? # nil means any day
    
    datetime.wday == day_of_week &&
      datetime.hour >= start_time.hour &&
      datetime.hour < end_time.hour
  end
  
  private
  
  def valid_time_range
    return unless start_time && end_time
    
    if end_time <= start_time
      errors.add(:end_time, '종료 시간은 시작 시간보다 늦어야 합니다')
    end
  end
end