class MakeupLesson < ApplicationRecord
  belongs_to :user
  
  STATUSES = %w[pending approved rejected completed cancelled].freeze
  SUBJECTS = %w[보컬 기타 믹스 작곡].freeze
  
  validates :teacher_name, presence: true
  validates :subject, presence: true, inclusion: { in: SUBJECTS }
  validates :status, inclusion: { in: STATUSES }
  validates :reason, presence: true
  validate :check_quota, on: :create
  validate :valid_requested_datetime
  
  scope :pending, -> { where(status: 'pending') }
  scope :approved, -> { where(status: 'approved') }
  scope :completed, -> { where(status: 'completed') }
  scope :recent, -> { order(created_at: :desc) }
  scope :upcoming, -> { where(status: 'approved').where('confirmed_datetime > ?', Time.current) }
  
  before_create :set_default_teacher
  after_create :increment_quota
  after_update :handle_status_change
  
  def approve!(datetime, location = nil, note = nil)
    update!(
      status: 'approved',
      confirmed_datetime: datetime,
      location: location || '모네뮤직 스튜디오',
      admin_note: note
    )
  end
  
  def reject!(reason = nil)
    update!(
      status: 'rejected',
      admin_note: reason
    )
    # 거절된 경우 쿼터 복구
    decrement_quota
  end
  
  def complete!
    update!(status: 'completed')
  end
  
  def cancel!
    if status == 'approved' || status == 'pending'
      update!(status: 'cancelled')
      decrement_quota
    end
  end
  
  def can_cancel?
    ['pending', 'approved'].include?(status) && 
    (confirmed_datetime.nil? || confirmed_datetime > 1.hour.from_now)
  end
  
  def status_badge_class
    case status
    when 'pending' then 'bg-yellow-100 text-yellow-800'
    when 'approved' then 'bg-green-100 text-green-800'
    when 'rejected' then 'bg-red-100 text-red-800'
    when 'completed' then 'bg-gray-100 text-gray-800'
    when 'cancelled' then 'bg-orange-100 text-orange-800'
    end
  end
  
  def status_display
    case status
    when 'pending' then '대기중'
    when 'approved' then '승인됨'
    when 'rejected' then '거절됨'
    when 'completed' then '완료'
    when 'cancelled' then '취소됨'
    end
  end
  
  private
  
  def set_default_teacher
    self.teacher_name ||= user.teacher if user.teacher.present?
  end
  
  def check_quota
    quota = find_or_create_quota
    if quota.used_count >= quota.max_count
      errors.add(:base, "이번 달 보충수업 신청 횟수(#{quota.max_count}회)를 초과했습니다")
    end
  end
  
  def valid_requested_datetime
    return unless requested_datetime.present?
    
    if requested_datetime < Time.current
      errors.add(:requested_datetime, '과거 시간은 신청할 수 없습니다')
    end
    
    if requested_datetime < 1.day.from_now
      errors.add(:requested_datetime, '최소 24시간 전에 신청해주세요')
    end
  end
  
  def find_or_create_quota
    current_date = Date.current
    MakeupQuota.find_or_create_by(
      user: user,
      year: current_date.year,
      month: current_date.month
    )
  end
  
  def increment_quota
    quota = find_or_create_quota
    quota.increment!(:used_count)
  end
  
  def decrement_quota
    quota = find_or_create_quota
    quota.decrement!(:used_count) if quota.used_count > 0
  end
  
  def handle_status_change
    return unless saved_change_to_status?
    
    old_status, new_status = saved_change_to_status
    
    # 취소나 거절 시 쿼터 복구
    if (old_status == 'pending' || old_status == 'approved') && 
       (new_status == 'cancelled' || new_status == 'rejected')
      decrement_quota
    end
  end
end