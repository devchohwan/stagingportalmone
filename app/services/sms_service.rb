require 'net/http'
require 'uri'
require 'json'
require 'digest'
require 'securerandom'
require 'openssl'

class SmsService
  def initialize
    @api_key = ENV['SOLAPI_API_KEY']
    @api_secret = ENV['SOLAPI_API_SECRET']
    @sender = ENV['SOLAPI_SENDER'] || ENV['SOLAPI_SENDER_PHONE']
    @base_url = 'https://api.solapi.com'
  end
  
  # 인증번호 발송
  def send_verification_code(phone, code)
    if @api_key.nil? || @api_secret.nil? || @sender.nil?
      Rails.logger.error "솔라피 환경변수가 설정되지 않았습니다."
      return { success: false, message: "SMS 발송 설정이 올바르지 않습니다." }
    end
    
    begin
      message = {
        to: phone.gsub('-', ''),
        from: @sender.gsub('-', ''),
        text: "[Monemusic] 인증번호는 #{code}입니다. (3분 이내 입력)"
      }
      
      result = send_sms(message)
      
      Rails.logger.info "SMS 발송 결과: #{result.inspect}"
      
      if result['statusCode'] == '2000'
        { success: true, message: "인증번호가 발송되었습니다." }
      else
        { success: false, message: "SMS 발송 실패: #{result['statusMessage'] || result['errorMessage'] || 'Unknown error'}" }
      end
    rescue => e
      Rails.logger.error "SMS 발송 오류: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      { success: false, message: "SMS 발송 중 오류가 발생했습니다." }
    end
  end
  
  # 회원가입 승인 알림
  def send_approval_notification(phone, name)
    if @api_key.nil? || @api_secret.nil? || @sender.nil?
      Rails.logger.error "솔라피 환경변수가 설정되지 않았습니다."
      return { success: false, message: "SMS 발송 설정이 올바르지 않습니다." }
    end
    
    begin
      message = {
        to: phone.gsub('-', ''),
        from: @sender.gsub('-', ''),
        text: "모네뮤직 회원 승인되셨습니다! 감사합니다."
      }
      
      Rails.logger.info "===== 승인 알림 SMS 전송 시도 ====="
      Rails.logger.info "수신번호: #{phone}"
      Rails.logger.info "발신번호: #{@sender}"
      Rails.logger.info "메시지: 모네뮤직 회원 승인되셨습니다! 감사합니다."
      
      result = send_sms(message)
      
      Rails.logger.info "SMS 전송 결과: #{result.inspect}"
      
      if result['statusCode'] == '2000'
        Rails.logger.info "SMS 전송 성공!"
        { success: true }
      else
        Rails.logger.error "SMS 전송 실패: #{result['statusMessage'] || result['errorMessage'] || 'Unknown error'}"
        { success: false }
      end
    rescue => e
      Rails.logger.error "승인 알림 SMS 오류: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      { success: false }
    end
  end
  
  # 예약 거절 알림
  def send_rejection_notification(phone, name)
    if @api_key.nil? || @api_secret.nil? || @sender.nil?
      Rails.logger.error "솔라피 환경변수가 설정되지 않았습니다."
      return { success: false, message: "SMS 발송 설정이 올바르지 않습니다." }
    end
    
    begin
      message = {
        to: phone.gsub('-', ''),
        from: @sender.gsub('-', ''),
        text: "[모네뮤직] 안녕하세요 #{name}님, 신청하신 예약이 거절되었습니다. 자세한 사항은 문의해 주세요."
      }
      
      Rails.logger.info "===== 거절 알림 SMS 전송 시도 ====="
      Rails.logger.info "수신번호: #{phone}"
      Rails.logger.info "발신번호: #{@sender}"
      Rails.logger.info "메시지: [모네뮤직] 안녕하세요 #{name}님, 신청하신 예약이 거절되었습니다."
      
      result = send_sms(message)
      
      Rails.logger.info "SMS 전송 결과: #{result.inspect}"
      
      if result['statusCode'] == '2000'
        Rails.logger.info "거절 알림 SMS 전송 성공!"
        { success: true }
      else
        Rails.logger.error "거절 알림 SMS 전송 실패: #{result['statusMessage'] || result['errorMessage'] || 'Unknown error'}"
        { success: false }
      end
    rescue => e
      Rails.logger.error "거절 알림 SMS 오류: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      { success: false }
    end
  end
  
  # 예약 확정 알림
  def send_reservation_confirmation(phone, date, time)
    if Rails.env.development?
      Rails.logger.info "===== 예약 확정 SMS (개발 모드) ====="
      Rails.logger.info "수신번호: #{phone}"
      Rails.logger.info "날짜/시간: #{date} #{time}"
      Rails.logger.info "===================================="
      return { success: true }
    end
    
    begin
      message = {
        to: phone.gsub('-', ''),
        from: @sender.gsub('-', ''),
        text: "[Monemusic] 예약이 확정되었습니다.\n날짜: #{date}\n시간: #{time}"
      }
      
      result = send_sms(message)
      { success: result['statusCode'] == '2000' }
    rescue => e
      Rails.logger.error "예약 확정 SMS 오류: #{e.message}"
      { success: false }
    end
  end

  private

  def send_sms(message)
    uri = URI(@base_url + '/messages/v4/send')
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    request = Net::HTTP::Post.new(uri)
    request['Content-Type'] = 'application/json'
    request['Authorization'] = generate_authorization_header
    request.body = {
      message: message
    }.to_json

    response = http.request(request)
    JSON.parse(response.body)
  end

  def generate_authorization_header
    date = Time.now.utc.iso8601(3)  # ISO8601 형식으로 밀리초까지 포함
    salt = SecureRandom.hex(16)
    # HMAC-SHA256 signature 생성 (공식 문서 기준)
    string_to_sign = date + salt
    signature = OpenSSL::HMAC.hexdigest('SHA256', @api_secret, string_to_sign)
    
    "HMAC-SHA256 apiKey=#{@api_key}, date=#{date}, salt=#{salt}, signature=#{signature}"
  end
end