class PitchPenalty < ApplicationRecord
  belongs_to :user

  validates :month, presence: true, inclusion: { in: 1..12 }
  validates :year, presence: true
  validates :user_id, uniqueness: { scope: [:month, :year] }

  def is_blocked?
    is_blocked
  end

  # 현재 월의 페널티 확인 또는 생성
  def self.for_user_this_month(user)
    current_month = Time.current.month
    current_year = Time.current.year

    find_or_create_by(
      user: user,
      month: current_month,
      year: current_year
    )
  end
end