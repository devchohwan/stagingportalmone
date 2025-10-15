class UserEnrollment < ApplicationRecord
  belongs_to :user
  has_many :lesson_deductions, dependent: :destroy
  has_many :enrollment_status_histories, dependent: :destroy
  has_many :enrollment_schedule_histories, dependent: :destroy

  # 콜백
  before_update :track_teacher_change
  before_update :track_schedule_change
  after_update :track_status_change

  # 요일 한글 변환
  def day_korean
    day_map = {
      'mon' => '월요일',
      'tue' => '화요일',
      'wed' => '수요일',
      'thu' => '목요일',
      'fri' => '금요일',
      'sat' => '토요일',
      'sun' => '일요일'
    }
    day_map[day] || day
  end

  # 시간 표시
  def time_display
    time_slot || ''
  end

  # 선생님 변경 이력 배열로 반환
  def teacher_history_array
    return [] if teacher_history.blank?
    teacher_history.split(' -> ')
  end

  # 선생님 변경 이력 문자열로 반환
  def teacher_history_display
    return teacher if teacher_history.blank?
    "#{teacher_history} -> #{teacher}"
  end

  # 정규 수업 자동 차감 (모든 활성 수강에 대해)
  def self.process_lesson_deductions
    # 활성 상태이고 남은 수업이 있는 수강만 처리
    active_enrollments = where(is_paid: true, status: 'active').where('remaining_lessons > 0')

    active_enrollments.each do |enrollment|
      enrollment.check_and_deduct_lessons
    end
  end

  # 개별 수강의 수업 차감 체크 (스케줄 이력 기반)
  def check_and_deduct_lessons
    return unless first_lesson_date.present?
    return if remaining_lessons <= 0

    # 요일을 숫자로 변환
    day_to_wday = { 'sun' => 0, 'mon' => 1, 'tue' => 2, 'wed' => 3, 'thu' => 4, 'fri' => 5, 'sat' => 6 }
    kst_zone = ActiveSupport::TimeZone['Seoul']
    today = Date.current

    # 첫 수업일부터 오늘까지 하루씩 확인
    current_date = first_lesson_date

    while current_date <= today
      # 이미 차감된 날짜는 건너뜀
      if already_deducted?(current_date)
        current_date += 1.day
        next
      end

      # 해당 날짜에 유효한 스케줄 찾기
      schedule = EnrollmentScheduleHistory.schedule_for_date(id, current_date)

      # 스케줄이 없으면 현재 스케줄 사용
      schedule_day = schedule&.day || day
      schedule_time_slot = schedule&.time_slot || time_slot

      next unless schedule_day.present? && schedule_time_slot.present?

      # 해당 날짜의 요일이 수업 요일과 일치하는지 확인
      target_wday = day_to_wday[schedule_day]
      if current_date.wday == target_wday
        # 수업 종료 시각 계산
        end_hour = schedule_time_slot.split('-').last.to_i
        lesson_end_time = kst_zone.local(current_date.year, current_date.month, current_date.day, end_hour, 0, 0)

        # 수업 종료 시각이 지났는지 확인
        if Time.current > lesson_end_time
          # 해당 날짜에 보강이나 패스가 있는지 확인
          has_makeup_or_pass = MakeupPassRequest.where(
            user_id: user_id,
            request_date: current_date
          ).where(status: ['active', 'completed']).exists?

          if has_makeup_or_pass
            # 보강이나 패스가 있으면 차감하지 않고 기록만 남김
            lesson_deductions.create!(
              deduction_date: current_date,
              deduction_time: lesson_end_time
            )
            Rails.logger.info "수업 차감 건너뜀 (보강/패스 존재): #{user.name} / #{current_date} / #{teacher}"
          else
            # 정규 수업 차감
            if remaining_lessons > 0
              decrement!(:remaining_lessons)
              lesson_deductions.create!(
                deduction_date: current_date,
                deduction_time: lesson_end_time
              )
              Rails.logger.info "정규 수업 차감: #{user.name} / #{current_date} / #{teacher} (#{schedule_day} #{schedule_time_slot}) / 남은 수업: #{remaining_lessons}"
            end
          end
        end
      end

      # 다음 날로 이동
      current_date += 1.day
    end
  end

  # 이미 차감되었는지 확인
  def already_deducted?(date)
    lesson_deductions.exists?(deduction_date: date)
  end

  # 다음 결제 예정일 계산 (휴원/패스 고려)
  def next_payment_date
    return nil unless first_lesson_date.present?

    # 1. 이 수강권에 결제된 총 수업 횟수 합산
    total_paid_lessons = Payment.where(enrollment_id: id).sum(:lessons)
    return nil if total_paid_lessons == 0

    # 2. 기본 마지막 수업일 = 첫수업일 + (총횟수 - 1) × 7일
    base_last_lesson_date = first_lesson_date + ((total_paid_lessons - 1) * 7).days

    # 3. 연장된 주 수 계산
    extended_weeks = calculate_extended_weeks(base_last_lesson_date)

    # 4. 최종 마지막 수업일
    actual_last_lesson_date = base_last_lesson_date + (extended_weeks * 7).days

    # 5. 다음 결제 예정일 = 마지막 수업일
    actual_last_lesson_date
  end

  # 연장된 주 수 계산 (패스 + 휴원)
  def calculate_extended_weeks(base_last_lesson_date)
    extended_weeks = 0

    # 요일 매핑
    day_to_wday = { 'sun' => 0, 'mon' => 1, 'tue' => 2, 'wed' => 3, 'thu' => 4, 'fri' => 5, 'sat' => 6 }
    target_wday = day_to_wday[day]
    return 0 unless target_wday

    # 첫수업일부터 매주 정규 수업일만 확인 (7일 단위로 점프)
    current_date = first_lesson_date
    end_date = base_last_lesson_date  # 로컬 변수로 복사
    max_iterations = 156 # 안전장치: 최대 156주 (3년)

    iteration = 0
    while current_date <= end_date && iteration < max_iterations
      # 패스 확인
      has_pass = MakeupPassRequest.where(
        user_id: user_id,
        request_date: current_date,
        request_type: 'pass',
        status: ['active', 'completed']
      ).exists?

      if has_pass
        extended_weeks += 1
        end_date += 7.days  # 패스가 있으면 마지막 날짜 연장
      end

      # 휴원 기간 확인 (해당 날짜에 이 수강권이 on_leave 상태였는지)
      if was_on_leave_at?(current_date)
        extended_weeks += 1
        end_date += 7.days  # 휴원이면 마지막 날짜 연장
      end

      current_date += 7.days  # 다음 주 같은 요일로 이동
      iteration += 1
    end

    extended_weeks
  end

  # 특정 날짜에 휴원 상태였는지 확인
  def was_on_leave_at?(date)
    # 해당 날짜 이전의 상태 변경 이력 중 가장 최근 것을 찾음
    last_status_change = enrollment_status_histories
                          .where('changed_at <= ?', date.end_of_day)
                          .order(changed_at: :desc)
                          .first

    # 이력이 없으면 현재 상태 기준
    return status == 'on_leave' unless last_status_change

    # 이력이 있으면 그 당시 상태
    last_status_change.status == 'on_leave'
  end

  private

  # 선생님 변경 추적
  def track_teacher_change
    if teacher_changed? && teacher_was.present?
      if teacher_history.blank?
        self.teacher_history = teacher_was
      else
        self.teacher_history = "#{teacher_history} -> #{teacher_was}"
      end
    end
  end

  # 스케줄 변경 추적 (요일/시간)
  def track_schedule_change
    if (day_changed? || time_slot_changed?) && (day_was.present? || time_slot_was.present?)
      # 변경 전 스케줄 기록 (아직 이력이 없는 경우)
      if enrollment_schedule_histories.empty? && first_lesson_date.present?
        enrollment_schedule_histories.create!(
          day: day_was || day,
          time_slot: time_slot_was || time_slot,
          changed_at: created_at || Time.current,
          effective_from: first_lesson_date
        )
      end

      # 새 스케줄 기록
      enrollment_schedule_histories.create!(
        day: day,
        time_slot: time_slot,
        changed_at: Time.current,
        effective_from: Date.current
      )
    end
  end

  # 상태 변경 추적 (휴원/복귀)
  def track_status_change
    if saved_change_to_status?
      enrollment_status_histories.create!(
        status: status,
        changed_at: Time.current,
        notes: "Status changed from #{status_before_last_save} to #{status}"
      )
    end
  end
end
