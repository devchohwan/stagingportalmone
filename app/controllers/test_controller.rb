class TestController < ApplicationController
  def simulate_login_with_phone_recovery
    # 전화번호 복구 시뮬레이션
    
    # 1. 기존 전화번호 (DB에서 가져온 것)
    old_phone = "01012345678"
    
    # 2. 변경된 전화번호 (모네뮤직 API에 저장된 것)
    new_phone = "01087654321"
    
    Rails.logger.info "=== 전화번호 복구 시뮬레이션 ==="
    Rails.logger.info "기존 전화번호: #{old_phone}"
    Rails.logger.info "변경된 전화번호 (모네뮤직): #{new_phone}"
    
    # 3. fetch_latest_user_info 시뮬레이션
    session[:user] = {}
    session[:user]['username'] = 'test_user'
    session[:user]['phone'] = old_phone  # 초기 상태
    
    Rails.logger.info "로그인 전 세션 전화번호: #{session[:user]['phone']}"
    
    # 4. 모네뮤직 API 호출 시뮬레이션 (성공)
    if Rails.env.development?
      # 실제로는 HTTParty.get을 호출하지만, 여기서는 시뮬레이션
      session[:user]['phone'] = new_phone
      Rails.logger.info "✅ 모네뮤직 API에서 최신 전화번호 가져옴: #{new_phone}"
    end
    
    Rails.logger.info "로그인 후 세션 전화번호: #{session[:user]['phone']}"
    
    render json: {
      status: 'success',
      message: '전화번호 복구 시뮬레이션 완료',
      old_phone: old_phone,
      new_phone: session[:user]['phone'],
      recovered: session[:user]['phone'] == new_phone
    }
  end
end