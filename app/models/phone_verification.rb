class PhoneVerification < ApplicationRecord
  validates :phone, presence: true
  validates :code, presence: true
  
  # 만료되지 않은 인증 찾기
  scope :active, -> { where('expires_at > ?', Time.current).where(verified: [false, nil]) }
  
  # 인증번호 생성
  def self.create_verification(phone)
    # 기존 미사용 인증번호 삭제
    where(phone: phone, verified: [false, nil]).destroy_all
    
    # 6자리 랜덤 숫자 생성
    code = rand(100000..999999).to_s
    
    create!(
      phone: phone.gsub('-', ''),
      code: code,
      verified: false,
      expires_at: 3.minutes.from_now
    )
  end
  
  # 인증번호 확인
  def verify!(input_code)
    return false if expired?
    return false if verified?
    return false if code != input_code
    
    update!(verified: true)
    true
  end
  
  # 만료 여부 확인
  def expired?
    expires_at < Time.current
  end
end
