class TeacherSchedule < ApplicationRecord
  belongs_to :user

  validates :teacher, presence: true
  validates :day, presence: true
  validates :time_slot, presence: true
  validates :user_id, presence: true
  validates :user_id, uniqueness: { scope: [:teacher, :day, :time_slot] }

  # 특정 날짜/시간/선생님의 실제 현재 인원 계산
  # 시간표 뷰어(load_schedule)와 동일한 로직 사용
  def self.current_count(date, time_slot, teacher)
    day_of_week = date.strftime('%a').downcase

    # 정규 스케줄 학생 가져오기
    schedules = where(teacher: teacher, day: day_of_week, time_slot: time_slot).includes(:user)

    active_students = 0

    schedules.each do |schedule|
      user = schedule.user
      next unless user # 삭제된 회원 skip

      # UserEnrollment 확인
      enrollment = UserEnrollment.find_by(
        user_id: user.id,
        teacher: teacher,
        day: day_of_week,
        time_slot: time_slot,
        is_paid: true
      )

      next unless enrollment # enrollment 없으면 skip

      # 첫수업일 체크
      if enrollment.first_lesson_date.present? && date < enrollment.first_lesson_date
        next # 첫수업일 전이면 skip
      end

      # 휴원 상태 체크
      if enrollment.status == 'on_leave'
        next # 휴원중이면 skip
      end

      # 남은 수업 횟수 체크
      if enrollment.remaining_lessons <= 0
        next # 수업 횟수 소진되면 skip
      end

      # 마지막 수업일 체크
      if enrollment.first_lesson_date.present? && enrollment.remaining_lessons > 0
        total_paid_lessons = Payment.where(user_id: user.id, teacher: teacher, subject: enrollment.subject).sum(:lessons)
        total_paid_lessons = enrollment.remaining_lessons if total_paid_lessons == 0

        last_lesson_date = enrollment.first_lesson_date + ((total_paid_lessons - 1) * 7).days

        if date > last_lesson_date
          next # 마지막 수업일 이후면 skip
        end
      end

      # 이 날짜에 패스 신청이 있는지 확인
      pass_request = MakeupPassRequest.where(
        user_id: user.id,
        request_type: 'pass',
        request_date: date,
        status: ['active', 'completed']
      ).first

      next if pass_request # 패스면 skip

      # 이 날짜에 보강으로 다른 곳에 가는지 확인
      makeup_away = MakeupPassRequest.where(
        user_id: user.id,
        request_type: 'makeup',
        request_date: date,
        status: ['active', 'completed']
      ).first

      next if makeup_away # 보강으로 이동하면 skip

      active_students += 1
    end

    # 이 날짜/시간/선생님으로 보강 온 학생 수 추가
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
