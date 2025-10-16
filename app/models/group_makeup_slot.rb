class GroupMakeupSlot < ApplicationRecord
  has_many :makeup_pass_requests, dependent: :nullify

  ALLOWED_DAYS = ['tue', 'sat'].freeze  # 화요일, 토요일만

  validates :teacher, presence: true
  validates :subject, presence: true
  validates :week_number, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :lesson_date, presence: true
  validates :day, presence: true, inclusion: {
    in: ALLOWED_DAYS,
    message: "믹싱 보강은 화요일과 토요일만 가능합니다"
  }
  validates :time_slot, presence: true
  validates :max_capacity, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :status, presence: true, inclusion: { in: %w[active closed cancelled] }

  scope :active, -> { where(status: 'active') }
  scope :for_subject, ->(subject) { where(subject: subject) }
  scope :for_week, ->(week) { where(week_number: week) }
  scope :on_date, ->(date) { where(lesson_date: date) }

  # 현재 예약 인원
  def current_count
    makeup_pass_requests
      .where(status: 'active')
      .count
  end

  # 예약 가능 여부
  def available?
    status == 'active' && current_count < max_capacity
  end

  # 남은 자리
  def remaining_slots
    [max_capacity - current_count, 0].max
  end

  # 특정 날짜/주차의 사용 가능한 슬롯들
  def self.available_for(date, subject, week_number)
    active
      .for_subject(subject)
      .for_week(week_number)
      .on_date(date)
      .select(&:available?)
  end

  # 시간 표시용
  def display_time
    return '' unless time_slot
    parts = time_slot.split('-')
    "#{parts[0]}:00-#{parts[1]}:00"
  end
end
