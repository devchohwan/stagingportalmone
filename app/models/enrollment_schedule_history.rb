class EnrollmentScheduleHistory < ApplicationRecord
  belongs_to :user_enrollment

  validates :day, presence: true
  validates :time_slot, presence: true
  validates :changed_at, presence: true
  validates :effective_from, presence: true

  # 특정 날짜에 유효한 스케줄 찾기
  def self.schedule_for_date(enrollment_id, date)
    where(user_enrollment_id: enrollment_id)
      .where('effective_from <= ?', date)
      .order(effective_from: :desc)
      .first
  end
end
