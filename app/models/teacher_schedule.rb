class TeacherSchedule < ApplicationRecord
  belongs_to :user

  validates :teacher, presence: true
  validates :day, presence: true
  validates :time_slot, presence: true
  validates :user_id, presence: true
  validates :user_id, uniqueness: { scope: [:teacher, :day, :time_slot] }

  # 특정 날짜/시간/선생님의 실제 현재 인원 계산
  # (정규 학생 - 빠진 학생 + 보강 온 학생)
  def self.current_count(date, time_slot, teacher)
    day_of_week = date.strftime('%a').downcase

    # 정규 스케줄 학생 수
    regular_count = where(teacher: teacher, day: day_of_week, time_slot: time_slot).count

    # 이 날짜에 보강/패스로 빠진 학생 수 (이 선생님의 정규 학생 중)
    away_count = MakeupPassRequest
      .joins("INNER JOIN teacher_schedules ON teacher_schedules.user_id = makeup_pass_requests.user_id")
      .where(status: 'active')
      .where("teacher_schedules.teacher = ? AND teacher_schedules.day = ? AND teacher_schedules.time_slot = ?",
             teacher, day_of_week, time_slot)
      .where(request_date: date)
      .count

    # 이 날짜/시간/선생님으로 보강 온 학생 수
    makeup_in_count = MakeupPassRequest
      .where(status: 'active', request_type: 'makeup')
      .where(makeup_date: date, time_slot: time_slot, teacher: teacher)
      .count

    # 실제 현재 인원
    regular_count - away_count + makeup_in_count
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
