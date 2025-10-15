class TeacherSchedule < ApplicationRecord
  belongs_to :user
  belongs_to :user_enrollment, optional: true

  validates :teacher, presence: true
  validates :day, presence: true
  validates :time_slot, presence: true
  validates :user_id, presence: true
  validates :lesson_date, uniqueness: { scope: [:user_id, :teacher, :day, :time_slot] }

  # 특정 날짜/시간/선생님의 실제 현재 인원 계산
  # 시간표 뷰어(load_schedule)와 동일한 로직 사용
  def self.current_count(date, time_slot, teacher)
    day_of_week = date.strftime('%a').downcase

    schedules = where(
      teacher: teacher, 
      day: day_of_week, 
      time_slot: time_slot,
      lesson_date: date,
      is_on_leave: false,
      is_absent: false
    ).includes(:user)

    active_students = schedules.count

    makeup_in_count = MakeupPassRequest
      .where(status: 'active', request_type: 'makeup')
      .where(makeup_date: date, time_slot: time_slot, teacher: teacher)
      .count

    active_students + makeup_in_count
  end

  # 남은 자리 수 (최대 3명)
  def self.available_slots(date, time_slot, teacher)
    count = current_count(date, time_slot, teacher)
    [3 - count, 0].max
  end

  # 자리가 있는지 확인
  def self.has_availability?(date, time_slot, teacher)
    available_slots(date, time_slot, teacher) > 0
  end
end
