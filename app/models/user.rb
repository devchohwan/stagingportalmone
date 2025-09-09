class User < ApplicationRecord
  has_secure_password
  
  # penalties 테이블과 연결 (practice 시스템의 페널티 데이터)
  has_many :penalties, dependent: :destroy
  has_many :reservations, dependent: :destroy
  
  validates :username, presence: true, uniqueness: true
  validates :name, presence: true
  validates :phone, format: { with: /\A(010|011|016|017|018|019)\d{7,8}\z/, message: "올바른 휴대폰 번호를 입력해주세요" }, allow_blank: true
  
  enum :status, { pending: 'pending', active: 'active', approved: 'approved', on_hold: 'on_hold', rejected: 'rejected' }, default: 'pending'
  
  scope :admins, -> { where(is_admin: true) }
  scope :regular_users, -> { where(is_admin: false) }
  scope :approved, -> { where(status: ['active', 'approved']) }
  
  def admin?
    is_admin
  end
  
  # Override enum approved? method to include both 'active' and 'approved' status
  def approved?
    status == 'active' || status == 'approved'
  end
  
  # Check if user is blocked (penalty system)
  def blocked?
    current_month_penalty.is_blocked
  end
  
  def display_name
    "#{name} (#{username})"
  end
  
  # 현재 달의 페널티 정보 가져오기 (practice 시스템과 동일)
  def current_month_penalty
    penalties.find_or_create_by(month: Date.current.month, year: Date.current.year) do |p|
      p.no_show_count = 0
      p.cancel_count = 0
      p.is_blocked = false
    end
  end
end
