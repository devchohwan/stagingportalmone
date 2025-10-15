class LessonDeduction < ApplicationRecord
  belongs_to :user_enrollment

  validates :user_enrollment_id, presence: true
  validates :deduction_date, presence: true, uniqueness: { scope: :user_enrollment_id }
  validates :deduction_time, presence: true

  before_validation :set_week_info, on: :create

  scope :by_week, ->(year_month, week_number) { where(year_month: year_month, week_number: week_number) }
  scope :by_year_month, ->(year_month) { where(year_month: year_month) }
  scope :in_week_range, ->(start_week, end_week) { where(week_number: start_week..end_week) }

  def self.calculate_week_number(date)
    ((date - date.beginning_of_month).to_i / 7) + 1
  end

  def self.format_year_month(date)
    date.strftime('%Y-%m')
  end

  private

  def set_week_info
    return unless deduction_date
    
    self.week_number = self.class.calculate_week_number(deduction_date)
    self.year_month = self.class.format_year_month(deduction_date)
  end
end
