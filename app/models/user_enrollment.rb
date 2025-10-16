require 'ostruct'

class UserEnrollment < ApplicationRecord
  belongs_to :user
  has_many :lesson_deductions, dependent: :destroy
  has_many :enrollment_status_histories, dependent: :destroy
  has_many :enrollment_schedule_histories, dependent: :destroy
  has_many :teacher_schedules, dependent: :nullify

  SUBJECTS_WITHOUT_PASS = ['믹싱'].freeze

  after_create :generate_schedules
  before_update :track_teacher_change
  before_update :track_schedule_change, unless: :skip_schedule_tracking?
  after_update :track_status_change
  after_update :regenerate_schedules_if_needed

  attr_accessor :skip_schedule_tracking

  scope :with_lesson_in_week, ->(year_month, week_number) {
    joins(:lesson_deductions).where(lesson_deductions: { year_month: year_month, week_number: week_number }).distinct
  }

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

  def time_display
    time_slot || ''
  end

  def lessons_by_week(year_month, week_number)
    lesson_deductions.by_week(year_month, week_number)
  end

  def lessons_by_month(year_month)
    lesson_deductions.by_year_month(year_month)
  end

  def teacher_history_array
    return [] if teacher_history.blank?
    teacher_history.split(' -> ')
  end

  def teacher_history_display
    return teacher if teacher_history.blank?
    "#{teacher_history} -> #{teacher}"
  end

  def current_week_number
    return 0 unless first_lesson_date
    
    last_schedule = TeacherSchedule.where(user_id: user_id)
                                   .order(:lesson_date)
                                   .last
    
    return 0 unless last_schedule
    
    ((last_schedule.lesson_date - first_lesson_date).to_i / 7) + 1
  end

  def next_week_number
    current_week_number + 1
  end

  def calculate_week_number(target_date)
    return 0 unless first_lesson_date
    return 0 if target_date < first_lesson_date
    
    # 해당 날짜 이전까지 차감된 수업 횟수 + 1
    deductions_before_date = lesson_deductions.where('deduction_date < ?', target_date).count
    deductions_before_date + 1
  end

  def self.process_lesson_deductions
    active_enrollments = where(is_paid: true, status: 'active').where('remaining_lessons > 0')

    active_enrollments.each do |enrollment|
      enrollment.check_and_deduct_lessons
    end
  end

  def check_and_deduct_lessons
    return unless first_lesson_date.present?
    return if remaining_lessons <= 0

    day_to_wday = { 'sun' => 0, 'mon' => 1, 'tue' => 2, 'wed' => 3, 'thu' => 4, 'fri' => 5, 'sat' => 6 }
    kst_zone = ActiveSupport::TimeZone['Seoul']
    today = Date.current

    current_date = first_lesson_date

    while current_date <= today
      if already_deducted?(current_date)
        current_date += 1.day
        next
      end

      schedules_for_date = enrollment_schedule_histories
        .where('effective_from <= ?', current_date)
        .where(day: current_date.strftime('%a').downcase)
        .order(changed_at: :desc)
        .to_a

      schedule_to_use = nil

      if schedules_for_date.empty?
        if current_date.strftime('%a').downcase == day
          schedule_to_use = OpenStruct.new(day: day, time_slot: time_slot)
        end
      else
        latest_schedule = schedules_for_date.first
        end_hour = latest_schedule.time_slot.split('-').last.to_i
        lesson_end_time = kst_zone.local(current_date.year, current_date.month, current_date.day, end_hour, 0, 0)

        if Time.current > lesson_end_time
          schedule_to_use = latest_schedule
        end
      end

      if schedule_to_use
        target_wday = day_to_wday[schedule_to_use.day]
        if current_date.wday == target_wday
          end_hour = schedule_to_use.time_slot.split('-').last.to_i
          lesson_end_time = kst_zone.local(current_date.year, current_date.month, current_date.day, end_hour, 0, 0)

          if Time.current > lesson_end_time
            has_makeup_or_pass = MakeupPassRequest.where(
              user_id: user_id,
              request_date: current_date
            ).where(status: ['active', 'completed']).exists?

            if has_makeup_or_pass
              lesson_deductions.create!(
                deduction_date: current_date,
                deduction_time: lesson_end_time
              )
              Rails.logger.info "수업 차감 건너뜀 (보강/패스 존재): #{user.name} / #{current_date} / #{teacher}"
            else
              if remaining_lessons > 0
                decrement!(:remaining_lessons)
                lesson_deductions.create!(
                  deduction_date: current_date,
                  deduction_time: lesson_end_time
                )
                Rails.logger.info "정규 수업 차감: #{user.name} / #{current_date} / #{teacher} (#{schedule_to_use.day} #{schedule_to_use.time_slot}) / 남은 수업: #{remaining_lessons}"
              end
            end
          end
        end
      end

      current_date += 1.day
    end
  end

  def already_deducted?(date)
    lesson_deductions.exists?(deduction_date: date)
  end

  def skip_schedule_tracking?
    @skip_schedule_tracking == true
  end

  def next_payment_date
    return nil unless first_lesson_date.present?

    last_schedule = TeacherSchedule.where(
      user_enrollment_id: id
    ).order(lesson_date: :desc).first
    
    return last_schedule&.lesson_date
  end

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

  def was_on_leave_at?(date)
    last_status_change = enrollment_status_histories
                          .where('changed_at <= ?', date.end_of_day)
                          .order(changed_at: :desc)
                          .first

    return status == 'on_leave' unless last_status_change

    last_status_change.status == 'on_leave'
  end

  def pass_enabled?
    !SUBJECTS_WITHOUT_PASS.include?(subject)
  end
  
  def generate_schedules(lessons_to_create = nil)
    return unless day.present? && time_slot.present? && first_lesson_date.present?
    
    lessons_count = lessons_to_create || total_lessons || remaining_lessons
    return if lessons_count <= 0
    
    day_to_wday = { 'sun' => 0, 'mon' => 1, 'tue' => 2, 'wed' => 3, 'thu' => 4, 'fri' => 5, 'sat' => 6 }
    target_wday = day_to_wday[day]
    return unless target_wday
    
    current_date = first_lesson_date
    if current_date.wday != target_wday
      current_date += 1.day until current_date.wday == target_wday
    end
    
    created_count = 0
    lessons_count.times do
      existing = TeacherSchedule.exists?(
        user_id: user_id,
        user_enrollment_id: id,
        lesson_date: current_date
      )
      
      unless existing
        TeacherSchedule.create!(
          user_id: user_id,
          teacher: teacher,
          day: day,
          time_slot: time_slot,
          lesson_date: current_date,
          is_on_leave: false,
          user_enrollment_id: id
        )
        created_count += 1
      end
      
      current_date += 7.days
    end
    
    Rails.logger.info "Generated #{created_count} schedules for enrollment ##{id}"
    created_count
  end
  
  def validate_schedule_consistency
    return { valid: true } unless first_lesson_date.present?
    
    expected_count = total_lessons || 0
    actual_count = teacher_schedules.count
    
    if expected_count != actual_count
      {
        valid: false,
        expected: expected_count,
        actual: actual_count,
        missing: expected_count - actual_count,
        message: "Expected #{expected_count} schedules but found #{actual_count}"
      }
    else
      { valid: true, count: actual_count }
    end
  end
  
  def fix_schedule_consistency
    validation = validate_schedule_consistency
    return validation if validation[:valid]
    
    if validation[:missing] > 0
      generate_schedules
      { fixed: true, created: validation[:missing] }
    else
      { fixed: false, message: "Too many schedules, manual intervention needed" }
    end
  end
  
  def regenerate_schedules_if_needed
    return if skip_schedule_tracking?
    
    if saved_change_to_total_lessons? || saved_change_to_day? || saved_change_to_time_slot?
      missing_schedules_count = total_lessons - teacher_schedules.count
      if missing_schedules_count > 0
        generate_schedules
      end
    end
  end

  private

  def track_teacher_change
    if teacher_changed? && teacher_was.present?
      if teacher_history.blank?
        self.teacher_history = teacher_was
      else
        self.teacher_history = "#{teacher_history} -> #{teacher_was}"
      end
    end
  end

  def track_schedule_change
    return unless (day_changed? || time_slot_changed?) && (day_was.present? || time_slot_was.present?)
    return unless day.present? && time_slot.present? # 스케줄 해제는 기록하지 않음

    # 첫 변경인 경우: 변경 전 스케줄도 함께 기록
    if enrollment_schedule_histories.empty? && first_lesson_date.present?
      enrollment_schedule_histories.create!(
        day: day_was,
        time_slot: time_slot_was,
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

  def track_status_change
    if saved_change_to_status?
      old_status = status_before_last_save
      new_status = status
      
      if new_status == 'on_leave'
        enrollment_status_histories.create!(
          status: new_status,
          changed_at: Time.current,
          notes: "#{Date.current.strftime('%Y년 %m월 %d일')}에 휴원"
        )
        create_on_leave_schedules
      elsif old_status == 'on_leave' && new_status == 'active'
        return_date = first_lesson_date || Date.current
        enrollment_status_histories.create!(
          status: new_status,
          changed_at: Time.current,
          notes: "#{return_date.strftime('%Y년 %m월 %d일')}에 복귀"
        )
        remove_on_leave_schedules_and_recreate
      else
        enrollment_status_histories.create!(
          status: new_status,
          changed_at: Time.current,
          notes: "Status changed from #{old_status} to #{new_status}"
        )
      end
    end
  end
  
  def create_on_leave_schedules
    return unless day.present? && time_slot.present? && remaining_lessons > 0
    
    TeacherSchedule.where(
      user_id: user_id,
      teacher: teacher,
      day: day,
      time_slot: time_slot
    ).where('lesson_date >= ?', Date.current).destroy_all
    
    day_to_wday = { 'sun' => 0, 'mon' => 1, 'tue' => 2, 'wed' => 3, 'thu' => 4, 'fri' => 5, 'sat' => 6 }
    target_wday = day_to_wday[day]
    return unless target_wday
    
    current_date = Date.current
    current_date += 1.day until current_date.wday == target_wday
    
    remaining_lessons.times do
      TeacherSchedule.create!(
        user_id: user_id,
        teacher: teacher,
        day: day,
        time_slot: time_slot,
        lesson_date: current_date,
        is_on_leave: true,
        user_enrollment_id: id
      )
      current_date += 7.days
    end
  end
  
  def remove_on_leave_schedules_and_recreate
    TeacherSchedule.where(
      user_enrollment_id: id
    ).where('lesson_date >= ?', Date.current).destroy_all
    
    return unless day.present? && time_slot.present? && remaining_lessons > 0
    
    day_to_wday = { 'sun' => 0, 'mon' => 1, 'tue' => 2, 'wed' => 3, 'thu' => 4, 'fri' => 5, 'sat' => 6 }
    target_wday = day_to_wday[day]
    return unless target_wday
    
    start_date = first_lesson_date || Date.current
    current_date = start_date
    current_date += 1.day until current_date.wday == target_wday
    
    remaining_lessons.times do
      TeacherSchedule.create!(
        user_id: user_id,
        teacher: teacher,
        day: day,
        time_slot: time_slot,
        lesson_date: current_date,
        is_on_leave: false,
        user_enrollment_id: id
      )
      current_date += 7.days
    end
  end
end
