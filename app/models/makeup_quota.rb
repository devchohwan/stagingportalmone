class MakeupQuota < ApplicationRecord
  belongs_to :user
  
  validates :year, presence: true
  validates :month, presence: true, inclusion: { in: 1..12 }
  validates :used_count, numericality: { greater_than_or_equal_to: 0 }
  validates :max_count, numericality: { greater_than: 0 }
  
  def remaining_count
    max_count - used_count
  end
  
  def can_request?
    used_count < max_count
  end
  
  def usage_percentage
    return 0 if max_count == 0
    (used_count.to_f / max_count * 100).round
  end
  
  def reset!
    update!(used_count: 0)
  end
end