class PitchRoom < ApplicationRecord
  has_many :pitch_reservations, dependent: :destroy

  validates :name, presence: true, uniqueness: true
  validates :seat_number, presence: true, uniqueness: true, inclusion: { in: [1, 2] }

  scope :active, -> { where(is_active: true) }

  def available_at?(start_time, end_time, exclude_reservation_id = nil)
    conflicting_reservations = pitch_reservations
      .where(status: ['pending', 'approved'])
      .where('start_time < ? AND end_time > ?', end_time, start_time)

    conflicting_reservations = conflicting_reservations.where.not(id: exclude_reservation_id) if exclude_reservation_id

    conflicting_reservations.empty?
  end

  def reservations_for_date(date)
    pitch_reservations
      .where(start_time: date.beginning_of_day..date.end_of_day)
      .where(status: ['pending', 'approved'])
      .order(:start_time)
  end
end