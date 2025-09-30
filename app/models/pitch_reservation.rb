class PitchReservation < ApplicationRecord
  belongs_to :user
  belongs_to :pitch_room

  validates :start_time, presence: true
  validates :end_time, presence: true
  validate :end_time_after_start_time
  validate :no_overlap_reservations
  validate :daily_limit
  validate :reservation_time_valid
  validate :cannot_cancel_if_approved

  scope :pending, -> { where(status: 'pending') }
  scope :approved, -> { where(status: 'approved') }
  scope :cancelled, -> { where(status: 'cancelled') }
  scope :active, -> { where(status: ['pending', 'approved']) }

  def approve!(admin_user)
    self.status = 'approved'
    self.approved_at = Time.current
    self.approved_by = admin_user.username
    save!
  end

  def cancel!(canceller)
    if status == 'approved'
      add_penalty_for_cancellation
    end

    self.status = 'cancelled'
    self.cancelled_at = Time.current
    self.cancelled_by = canceller.username
    save!
  end

  def can_cancel?
    (status == 'pending' || status == 'approved') && start_time > 30.minutes.from_now
  end

  def status_display
    case status
    when 'pending' then '승인 대기'
    when 'approved' then '수업 대기'
    when 'completed' then '완료'
    when 'cancelled' then '취소됨'
    when 'rejected' then '거절됨'
    when 'no_show' then '노쇼'
    else status
    end
  end

  # 시간이 지난 예약 상태 자동 업데이트
  def self.update_status_by_time!
    # 승인된 예약 중 시간이 지난 것들을 완료로 변경
    where(status: 'approved')
      .where('end_time < ?', Time.current)
      .update_all(status: 'completed')

    # 승인 대기 중 시간이 지난 것들을 자동 취소
    where(status: 'pending')
      .where('start_time < ?', Time.current)
      .update_all(status: 'cancelled', cancelled_at: Time.current, cancelled_by: 'system')
  end

  # 페널티 적용 후 콜백
  after_update :apply_penalty_if_needed

  private

  def apply_penalty_if_needed
    if saved_change_to_status? && status == 'no_show'
      add_penalty_for_no_show
    end
  end

  def add_penalty_for_cancellation
    penalty = user.pitch_penalty
    penalty.increment!(:penalty_count)
    penalty.increment!(:cancel_count)

    if penalty.penalty_count >= 3
      penalty.update!(is_blocked: true)
    end
  end

  def add_penalty_for_no_show
    penalty = user.pitch_penalty
    penalty.increment!(:penalty_count)
    penalty.increment!(:no_show_count)

    if penalty.penalty_count >= 3
      penalty.update!(is_blocked: true)
    end
  end

  def end_time_after_start_time
    return unless start_time && end_time
    errors.add(:end_time, '종료 시간은 시작 시간 이후여야 합니다') if end_time <= start_time
  end

  def no_overlap_reservations
    return unless start_time && end_time && pitch_room

    overlapping = PitchReservation.active
      .where(pitch_room: pitch_room)
      .where('start_time < ? AND end_time > ?', end_time, start_time)
      .where.not(id: id)

    errors.add(:base, '해당 시간대에 이미 예약이 있습니다') if overlapping.exists?
  end

  def daily_limit
    return unless start_time && user

    today_reservations = user.pitch_reservations.active
      .where('DATE(start_time) = ?', start_time.to_date)
      .where.not(id: id)

    errors.add(:base, '하루에 한 번만 예약할 수 있습니다') if today_reservations.exists?
  end

  def reservation_time_valid
    return unless start_time && end_time

    hour = start_time.hour
    if hour < 9 || hour >= 22
      errors.add(:start_time, '예약 가능 시간은 오전 9시부터 오후 10시까지입니다')
    end

    duration = (end_time - start_time) / 3600.0
    if duration != 1.0
      errors.add(:base, '예약은 1시간 단위로만 가능합니다')
    end
  end

  def cannot_cancel_if_approved
    if status_was == 'approved' && status == 'cancelled' && !cancelled_by
      errors.add(:status, '승인된 예약은 취소할 수 없습니다')
    end
  end


end