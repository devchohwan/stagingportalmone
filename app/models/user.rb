class User < ApplicationRecord
  # Devise의 encrypted_password를 사용하기 위해 has_secure_password 제거
  
  # 담당 선생님 목록 상수
  TEACHERS = ['무성', '성균', '노네임', '로한', '범석', '두박', '오또', '지명', '도현', '온라인'].freeze
  
  # penalties 테이블과 연결 (practice 시스템의 페널티 데이터)
  has_many :penalties, dependent: :destroy
  has_many :reservations, dependent: :destroy
  has_many :makeup_reservations, dependent: :destroy
  has_many :makeup_pass_requests, dependent: :destroy
  has_many :pitch_reservations, dependent: :destroy
  has_many :pitch_penalties, dependent: :destroy
  has_many :payments, dependent: :destroy
  has_many :user_enrollments, dependent: :destroy
  has_many :teacher_schedules, dependent: :destroy
  
  # makeup system에서는 MakeupUser를 통해 연결
  
  validates :username, presence: true, uniqueness: true
  validates :name, presence: true
  validates :phone, format: { with: /\A(010|011|016|017|018|019)\d{7,8}\z/, message: "올바른 휴대폰 번호를 입력해주세요" }, allow_blank: true
  
  enum :status, { pending: 'pending', active: 'active', approved: 'approved', on_hold: 'on_hold', rejected: 'rejected', on_leave: 'on_leave' }, default: 'pending'
  
  scope :admins, -> { where(is_admin: true) }
  scope :regular_users, -> { where(is_admin: false) }
  scope :approved, -> { where(status: ['active', 'approved']) }
  
  def admin?
    is_admin
  end
  
  def teacher?
    is_admin && teacher_name.present?
  end
  
  # Override enum approved? method to include both 'active' and 'approved' status
  def approved?
    status == 'active' || status == 'approved'
  end
  
  # Check if user is blocked (penalty system)
  def blocked?
    current_month_penalty.is_blocked
  end

  # Check if user is on leave (all enrollments are on_leave)
  def on_leave?
    active_enrollments = user_enrollments.where(is_paid: true).where('remaining_lessons > 0')
    return false if active_enrollments.empty?
    active_enrollments.all? { |e| e.status == 'on_leave' }
  end

  def display_name
    "#{name} (#{username})"
  end

  # 담당 선생님 목록 (UserEnrollment 기반)
  def teachers
    user_enrollments.where(is_paid: true)
                    .where('remaining_lessons > 0')
                    .pluck(:teacher)
                    .uniq
  end

  # 주 담당 선생님 (첫 번째 활성 수강)
  def primary_teacher
    teachers.first || self[:teacher] || '미배정'
  end
  
  # 현재 달의 페널티 정보 가져오기 (practice 시스템과 동일)
  def current_month_penalty(system_type = 'practice')
    penalties.find_or_create_by(month: Date.current.month, year: Date.current.year, system_type: system_type) do |p|
      p.no_show_count = 0
      p.cancel_count = 0
      p.is_blocked = false
    end
  end
  
  # 연습실 전용 페널티
  def practice_penalty
    current_month_penalty('practice')
  end
  
  # 보충수업 전용 페널티
  def makeup_penalty
    current_month_penalty('makeup')
  end

  # 음정수업 전용 페널티
  def pitch_penalty
    PitchPenalty.for_user_this_month(self)
  end

  # 정규 수업일시 가져오기 (스케줄 관리에서 설정된 정보)
  def regular_lesson_schedule
    # UserEnrollment에서 활성 스케줄 찾기 (day와 time_slot이 있는 첫 번째)
    enrollment = user_enrollments.where(is_paid: true)
                                 .where.not(day: nil, time_slot: nil)
                                 .where('remaining_lessons > 0')
                                 .first

    return nil unless enrollment

    {
      day: enrollment.day,
      time_slot: enrollment.time_slot,
      day_korean: day_to_korean(enrollment.day),
      time_display: enrollment.time_slot.split('-').first,
      teacher: enrollment.teacher
    }
  end

  # 이번 수업일 계산 (오늘 기준 다음에 오는 수업일)
  def next_lesson_date
    now = Time.current
    kst_zone = ActiveSupport::TimeZone['Seoul']
    
    schedules = TeacherSchedule.where(user_id: id)
                               .where('lesson_date >= ?', Date.current)
                               .where(is_absent: false)
                               .order(:lesson_date)
    
    schedules.each do |schedule|
      end_hour = schedule.time_slot.split('-').last.to_i
      lesson_end_time = kst_zone.local(schedule.lesson_date.year, schedule.lesson_date.month, schedule.lesson_date.day, end_hour, 0, 0)
      
      if lesson_end_time > now
        return schedule.lesson_date
      end
    end
    
    nil
  end

  def prev_lesson_date
    now = Time.current
    kst_zone = ActiveSupport::TimeZone['Seoul']
    
    schedules = TeacherSchedule.where(user_id: id)
                               .where('lesson_date <= ?', Date.current)
                               .where(is_absent: false)
                               .order(lesson_date: :desc)
    
    schedules.each do |schedule|
      end_hour = schedule.time_slot.split('-').last.to_i
      lesson_end_time = kst_zone.local(schedule.lesson_date.year, schedule.lesson_date.month, schedule.lesson_date.day, end_hour, 0, 0)
      
      if lesson_end_time <= now
        return schedule.lesson_date
      end
    end
    
    nil
  end

  def following_lesson_date
    next_date = next_lesson_date
    return nil unless next_date

    TeacherSchedule.where(user_id: id)
                   .where('lesson_date > ?', next_date)
                   .where(is_absent: false)
                   .order(:lesson_date)
                   .first
                   &.lesson_date
  end

  def next_lesson_datetime
    next_schedule = TeacherSchedule.where(user_id: id)
                                   .where('lesson_date >= ?', Date.current)
                                   .where(is_absent: false)
                                   .order(:lesson_date)
                                   .first
    return nil unless next_schedule

    start_hour = next_schedule.time_slot.split('-').first.to_i
    Time.zone.local(next_schedule.lesson_date.year, next_schedule.lesson_date.month, 
                    next_schedule.lesson_date.day, start_hour, 0, 0)
  end

  # 다음 수업 전까지 취소한 이력이 있는지 확인
  def has_cancelled_makeup_before_next_lesson?(enrollment_id = nil)
    return false unless next_lesson_date

    # 가장 최근에 취소된 보강이 있는지 확인
    query = makeup_pass_requests
      .where(status: 'cancelled', request_type: 'makeup')

    # enrollment_id가 지정되면 해당 과목만 확인
    query = query.where(user_enrollment_id: enrollment_id) if enrollment_id

    last_cancelled = query.order(updated_at: :desc).first

    return false unless last_cancelled

    # 취소 이후 다음 수업일이 아직 지나지 않았으면 제한
    last_cancelled.updated_at > (next_lesson_date - 7.days) && Date.current < next_lesson_date
  end

  # 마지막 수업일 + 시간 계산 (모든 수강 중 가장 늦은 마지막 수업)
  def last_lesson_end_time
    active_enrollments = user_enrollments.where(is_paid: true, status: 'active')
                                         .where('remaining_lessons > 0')

    return nil if active_enrollments.empty?

    latest_end_time = nil

    active_enrollments.each do |enrollment|
      next unless enrollment.first_lesson_date.present? && enrollment.time_slot.present?

      # 총 결제 수업 횟수 = Payment의 lessons 합계
      total_paid_lessons = Payment.where(user_id: id, teacher: enrollment.teacher, subject: enrollment.subject).sum(:lessons)

      # Payment가 없으면 remaining_lessons를 기준으로 계산
      total_paid_lessons = enrollment.remaining_lessons if total_paid_lessons == 0

      # 마지막 수업일 = 첫수업일 + (총 수업 횟수 - 1) * 7일
      last_lesson_date = enrollment.first_lesson_date + ((total_paid_lessons - 1) * 7).days

      # 수업 종료 시각 = 마지막 수업일 + 수업 시간대 종료 시각
      time_parts = enrollment.time_slot.split('-')
      end_hour = time_parts[1].to_i
      end_time = last_lesson_date.to_time.in_time_zone + end_hour.hours

      # 가장 늦은 시각 찾기
      latest_end_time = end_time if latest_end_time.nil? || end_time > latest_end_time
    end

    latest_end_time
  end

  # 남은 패스 횟수 (UserEnrollment 기반 - Single Source of Truth)
  def current_remaining_passes
    user_enrollments.where(is_paid: true).sum(:remaining_passes)
  end

  # 비밀번호 업데이트 메서드
  def password=(new_password)
    return if new_password.blank?

    # BCrypt로 해시화
    hashed = ::BCrypt::Password.create(new_password)

    # Production DB uses encrypted_password, development might use password_digest
    if self.attributes.key?('encrypted_password')
      self[:encrypted_password] = hashed
    elsif self.attributes.key?('password_digest')
      self[:password_digest] = hashed
    else
      # If neither exists, add encrypted_password column dynamically
      self[:encrypted_password] = hashed
    end
  end
  
  # Devise compatible authenticate method
  def authenticate(password)
    # Production DB uses encrypted_password, development uses password_digest
    password_field = self.attributes.key?('encrypted_password') ? self[:encrypted_password] : self[:password_digest]

    return false unless password_field.present?

    # BCrypt to verify passwords
    bcrypt_password = ::BCrypt::Password.new(password_field)
    bcrypt_password == password
  rescue BCrypt::Errors::InvalidHash
    false
  end

  private

  def day_to_korean(day)
    {
      'mon' => '월',
      'tue' => '화',
      'wed' => '수',
      'thu' => '목',
      'fri' => '금',
      'sat' => '토',
      'sun' => '일'
    }[day] || day
  end

  def korean_day_to_wday(day)
    {
      'mon' => 1,
      'tue' => 2,
      'wed' => 3,
      'thu' => 4,
      'fri' => 5,
      'sat' => 6,
      'sun' => 0
    }[day] || 0
  end
end
