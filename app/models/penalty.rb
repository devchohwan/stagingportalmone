class Penalty < ApplicationRecord
  belongs_to :user
  
  # 기본값 설정
  after_initialize :set_defaults, if: :new_record?
  
  def set_defaults
    self.no_show_count ||= 0
    self.cancel_count ||= 0
    self.is_blocked ||= false
  end
  
  def total_violations
    (no_show_count || 0) + (cancel_count || 0)
  end
  
  def is_blocked?
    is_blocked == true
  end
end