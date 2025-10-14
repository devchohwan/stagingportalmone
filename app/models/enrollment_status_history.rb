class EnrollmentStatusHistory < ApplicationRecord
  belongs_to :user_enrollment

  validates :status, presence: true, inclusion: { in: %w[active on_leave] }
  validates :changed_at, presence: true

  scope :chronological, -> { order(changed_at: :asc) }
  scope :reverse_chronological, -> { order(changed_at: :desc) }
end
