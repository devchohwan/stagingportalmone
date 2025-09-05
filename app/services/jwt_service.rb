class JwtService
  # 모든 프로젝트가 동일한 시크릿 키를 사용해야 JWT 토큰 공유 가능
  SECRET_KEY = 'shared-secret-key-for-monemusic-projects-2024'

  def self.generate_portal_token(user)
    payload = {
      user_id: user.id,
      username: user.username,
      is_admin: user.is_admin,
      exp: 24.hours.from_now.to_i
    }
    
    JWT.encode(payload, SECRET_KEY, 'HS256')
  end

  def self.decode(token)
    begin
      decoded = JWT.decode(token, SECRET_KEY, true, { algorithm: 'HS256' })[0]
      HashWithIndifferentAccess.new(decoded)
    rescue JWT::DecodeError, JWT::ExpiredSignature
      nil
    end
  end
end