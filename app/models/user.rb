class User < ApplicationRecord
  # Devise의 encrypted_password를 사용하기 위해 has_secure_password 제거
  
  # 담당 선생님 목록 상수
  TEACHERS = ['무성', '성균', '노네임', '로한', '범석', '두박', '오또', '지명', '도현', '온라인'].freeze
  
  # penalties 테이블과 연결 (practice 시스템의 페널티 데이터)
  has_many :penalties, dependent: :destroy
  has_many :reservations, dependent: :destroy
  has_many :makeup_lessons, dependent: :destroy
  has_many :makeup_reservations, dependent: :destroy
  has_many :makeup_quotas, dependent: :destroy
  
  # makeup system에서는 MakeupUser를 통해 연결
  
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
  def current_month_penalty(system_type = 'practice')
    penalties.find_or_create_by(month: Date.current.month, year: Date.current.year, system_type: system_type) do |p|
      p.no_show_count = 0
      p.cancel_count = 0
      p.is_blocked = false
    end
  end
  
  # 연습실 전용 페널티
  def practice_penalty
    current_month_penalty('practice')
  end
  
  # 보충수업 전용 페널티
  def makeup_penalty
    current_month_penalty('makeup')
  end
  
  # 비밀번호 업데이트 메서드
  def password=(new_password)
    return if new_password.blank?
    
    # BCrypt로 해시화
    hashed = ::BCrypt::Password.create(new_password)
    
    # Production DB uses encrypted_password, development might use password_digest
    if self.attributes.key?('encrypted_password')
      self[:encrypted_password] = hashed
    elsif self.attributes.key?('password_digest')
      self[:password_digest] = hashed
    else
      # If neither exists, add encrypted_password column dynamically
      self[:encrypted_password] = hashed
    end
  end
  
  # Devise compatible authenticate method
  def authenticate(password)
    # Production DB uses encrypted_password, development uses password_digest
    password_field = self.attributes.key?('encrypted_password') ? self[:encrypted_password] : self[:password_digest]
    
    return false unless password_field.present?
    
    # BCrypt to verify passwords
    bcrypt_password = ::BCrypt::Password.new(password_field)
    bcrypt_password == password
  rescue BCrypt::Errors::InvalidHash
    false
  end
end
