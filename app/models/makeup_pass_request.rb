class MakeupPassRequest < ApplicationRecord
  belongs_to :user

  validates :request_type, presence: true, inclusion: { in: %w[makeup pass] }
  validates :request_date, presence: true
  validates :week_number, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :content, presence: true
  validates :status, presence: true, inclusion: { in: %w[active completed cancelled no_show] }

  # 보강일 경우 시간과 선생님 필수
  validates :time_slot, presence: true, if: :makeup?
  validates :teacher, presence: true, if: :makeup?

  scope :active, -> { where(status: 'active') }
  scope :completed, -> { where(status: 'completed') }
  scope :cancelled, -> { where(status: 'cancelled') }
  scope :no_show, -> { where(status: 'no_show') }
  scope :makeup_requests, -> { where(request_type: 'makeup') }
  scope :pass_requests, -> { where(request_type: 'pass') }
  scope :recent, -> { order(created_at: :desc) }

  def makeup?
    request_type == 'makeup'
  end

  def pass?
    request_type == 'pass'
  end

  def cancel!
    ActiveRecord::Base.transaction do
      update!(status: 'cancelled', cancelled_at: Time.current)

      # 보강 취소 시: 원래 자리(request_date)의 스케줄을 결석 처리하고 수업 횟수 차감
      if makeup?
        # request_date의 요일 구하기
        day_name = { 0 => 'sun', 1 => 'mon', 2 => 'tue', 3 => 'wed', 4 => 'thu', 5 => 'fri', 6 => 'sat' }[request_date.wday]

        # 원래 스케줄 찾기 (UserEnrollment 기반)
        enrollment = user.user_enrollments.find_by(
          is_paid: true,
          day: day_name
        )

        if enrollment
          # TeacherSchedule 찾아서 결석 처리
          schedule = TeacherSchedule.find_by(
            user_id: user_id,
            teacher: enrollment.teacher,
            day: day_name,
            time_slot: enrollment.time_slot
          )

          if schedule && !schedule.is_absent
            schedule.update!(is_absent: true)
            enrollment.decrement!(:remaining_lessons)
            Rails.logger.info "보강 취소: #{user.name} 님 결석 처리 (남은 수업: #{enrollment.remaining_lessons})"
          end
        end
      end
    end
  end

  def complete!
    ActiveRecord::Base.transaction do
      update!(status: 'completed')

      # 보강 완료 시 수업 차감 (보강만, 패스는 신청 시 이미 차감됨)
      if makeup?
        # 보강 받은 선생님의 UserEnrollment 찾기
        enrollment = user.user_enrollments.find_by(
          teacher: teacher,
          is_paid: true
        )

        if enrollment && enrollment.remaining_lessons > 0
          enrollment.decrement!(:remaining_lessons)
          Rails.logger.info "보강 완료: #{user.name} / #{teacher} / #{makeup_date} / 남은 수업: #{enrollment.remaining_lessons}"
        end
      end
    end
  end

  def mark_no_show!
    update(status: 'no_show')
  end

  def formatted_date
    # 보강인 경우 보강 받을 날짜 표시, 패스인 경우 패스할 날짜 표시
    date_to_show = makeup? && makeup_date ? makeup_date : request_date
    date_to_show.strftime('%Y년 %m월 %d일')
  end

  def formatted_time
    return nil unless time_slot
    parts = time_slot.split('-')
    "#{parts[0]}:00-#{parts[1]}:00"
  end

  # 상태 자동 업데이트 (연습실 로직과 동일)
  def self.update_statuses
    now = Time.current

    # Active 상태인 예약들 확인
    active.find_each do |request|
      # 패스인 경우: request_date 기준
      # 보강인 경우: makeup_date 기준
      target_date = request.makeup? && request.makeup_date ? request.makeup_date : request.request_date

      if request.makeup?
        # 보강은 시간까지 고려
        time_parts = request.time_slot.split('-')
        end_hour = time_parts[1].to_i
        end_time = target_date.to_time + end_hour.hours

        if now > end_time
          # 종료 시간 지나면 완료
          request.complete!
        end
      else
        # 패스는 날짜만 고려 (자정 지나면 완료)
        if now.to_date > target_date
          request.complete!
        end
      end
    end
  end

  # 보강 취소 시 원래 자리로 돌아갈 수 있는지 확인
  def can_return_to_original_slot?
    return true unless makeup? # 패스는 항상 가능

    schedule = user.regular_lesson_schedule
    return true unless schedule # 정규 수업이 없으면 항상 가능

    original_day = schedule[:day]
    original_time_slot = schedule[:time_slot]
    original_teacher = schedule[:teacher]

    # 원래 자리의 현재 인원 체크 (자신을 제외하고)
    # 현재 active 상태인 보강 신청 중, 원래 자리로 이동한 학생 수
    moved_to_original_slot = MakeupPassRequest.joins(:user)
      .where(status: 'active', request_type: 'makeup')
      .where(makeup_date: request_date, time_slot: original_time_slot, teacher: original_teacher)
      .where.not(user_id: user_id)
      .count

    # 원래 정규 수업생 중 보강/패스 안 한 학생 수
    regular_students = TeacherSchedule
      .where(day: original_day, time_slot: original_time_slot, teacher: original_teacher)
      .where.not(user_id: user_id)
      .count

    # 보강/패스로 빠진 학생 수
    away_students = MakeupPassRequest.joins(:user)
      .joins("INNER JOIN teacher_schedules ON teacher_schedules.user_id = makeup_pass_requests.user_id")
      .where(status: 'active')
      .where("teacher_schedules.day = ? AND teacher_schedules.time_slot = ? AND teacher_schedules.teacher = ?",
             original_day, original_time_slot, original_teacher)
      .where("makeup_pass_requests.request_date = ?", request_date)
      .where.not(user_id: user_id)
      .count

    current_count = regular_students - away_students + moved_to_original_slot

    # 3명 미만이면 돌아갈 수 있음
    current_count < 3
  end
end
