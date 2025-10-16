class MakeupPassRequest < ApplicationRecord
  belongs_to :user
  belongs_to :user_enrollment, optional: true

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

      if makeup?
        schedule = TeacherSchedule.find_by(
          user_id: user_id,
          lesson_date: request_date
        )

        if schedule
          # 이미 결석 처리되어 있지 않으면 결석 처리
          if !schedule.is_absent
            schedule.update!(is_absent: true)
          end
          
          # 보강 취소 시는 항상 수업 횟수 차감 (원래 자리가 결석 처리되어 있더라도)
          enrollment = user.user_enrollments.find_by(
            is_paid: true,
            teacher: schedule.teacher
          )
          
          if enrollment
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
        # 유저의 활성 수강권 중 남은 수업이 있는 것 찾기 (보강은 다른 선생님한테 받을 수 있음)
        enrollment = user.user_enrollments
          .where(is_paid: true, status: 'active')
          .where('remaining_lessons > 0')
          .order(first_lesson_date: :asc)
          .first

        if enrollment
          enrollment.decrement!(:remaining_lessons)
          Rails.logger.info "보강 완료: #{user.name} / 보강선생님: #{teacher} / 차감수강권: #{enrollment.teacher} / #{makeup_date} / 남은 수업: #{enrollment.remaining_lessons}"
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
    kst_zone = ActiveSupport::TimeZone['Seoul']

    # Active 상태인 예약들 확인
    active.find_each do |request|
      # 패스인 경우: request_date 기준
      # 보강인 경우: makeup_date 기준
      target_date = request.makeup? && request.makeup_date ? request.makeup_date : request.request_date

      if request.makeup?
        # 보강은 시간까지 고려 (한국 시각 기준)
        time_parts = request.time_slot.split('-')
        end_hour = time_parts[1].to_i
        end_time = kst_zone.local(target_date.year, target_date.month, target_date.day, end_hour, 0, 0)

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
    return true unless makeup?

    original_schedule = TeacherSchedule.find_by(
      user_id: user_id,
      lesson_date: request_date
    )
    return true unless original_schedule

    original_teacher = original_schedule.teacher
    original_time_slot = original_schedule.time_slot

    moved_to_original_slot = MakeupPassRequest.joins(:user)
      .where(status: 'active', request_type: 'makeup')
      .where(makeup_date: request_date, time_slot: original_time_slot, teacher: original_teacher)
      .where.not(user_id: user_id)
      .count

    regular_students = TeacherSchedule
      .where(lesson_date: request_date, time_slot: original_time_slot, teacher: original_teacher)
      .where.not(user_id: user_id)
      .count

    away_students = MakeupPassRequest.joins(:user)
      .joins("INNER JOIN teacher_schedules ON teacher_schedules.user_id = makeup_pass_requests.user_id")
      .where(status: 'active')
      .where("teacher_schedules.lesson_date = ? AND teacher_schedules.time_slot = ? AND teacher_schedules.teacher = ?",
             request_date, original_time_slot, original_teacher)
      .where("makeup_pass_requests.request_date = ?", request_date)
      .where.not(user_id: user_id)
      .count

    current_count = regular_students - away_students + moved_to_original_slot

    current_count < 3
  end
end
