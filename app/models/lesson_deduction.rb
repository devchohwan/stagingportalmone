class LessonDeduction < ApplicationRecord
  belongs_to :user_enrollment

  validates :user_enrollment_id, presence: true
  validates :deduction_date, presence: true, uniqueness: { scope: :user_enrollment_id }
  validates :deduction_time, presence: true
end
