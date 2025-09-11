class Api::PhoneVerificationsController < ApplicationController
  skip_before_action :verify_authenticity_token
  skip_before_action :require_login, if: -> { defined?(require_login) }
  skip_before_action :authenticate_user!, if: -> { defined?(authenticate_user!) }
  skip_before_action :update_reservation_statuses
  
  # POST /api/send-verification
  def send_code
    phone = params[:phone]&.gsub('-', '')
    
    if phone.blank? || phone.length != 11
      render json: { success: false, message: "올바른 전화번호를 입력해주세요." }, status: :bad_request
      return
    end
    
    begin
      # 인증번호 생성 및 저장
      verification = PhoneVerification.create_verification(phone)
      
      # SMS 발송
      sms_service = SmsService.new
      result = sms_service.send_verification_code(phone, verification.code)
      
      if result[:success]
        session[:phone_verification_id] = verification.id
        render json: { success: true, message: result[:message] }
      else
        render json: { success: false, message: result[:message] }, status: :unprocessable_entity
      end
    rescue => e
      Rails.logger.error "Phone verification error: #{e.message}"
      render json: { success: false, message: "인증번호 발송 중 오류가 발생했습니다." }, status: :internal_server_error
    end
  end
  
  # POST /api/verify-code
  def verify_code
    code = params[:code]
    verification_id = session[:phone_verification_id]
    
    if code.blank? || code.length != 6
      render json: { success: false, message: "6자리 인증번호를 입력해주세요." }, status: :bad_request
      return
    end
    
    if verification_id.blank?
      render json: { success: false, message: "인증번호를 먼저 발송해주세요." }, status: :bad_request
      return
    end
    
    begin
      verification = PhoneVerification.find(verification_id)
      
      if verification.expired?
        render json: { success: false, message: "인증번호가 만료되었습니다. 다시 발송해주세요." }, status: :unprocessable_entity
      elsif verification.verified?
        render json: { success: false, message: "이미 인증된 번호입니다." }, status: :unprocessable_entity
      elsif verification.verify!(code)
        session[:phone_verified] = true
        session[:verified_phone] = verification.phone
        render json: { success: true, message: "인증이 완료되었습니다." }
      else
        render json: { success: false, message: "인증번호가 일치하지 않습니다." }, status: :unprocessable_entity
      end
    rescue ActiveRecord::RecordNotFound
      render json: { success: false, message: "인증 정보를 찾을 수 없습니다." }, status: :not_found
    rescue => e
      Rails.logger.error "Code verification error: #{e.message}"
      render json: { success: false, message: "인증 확인 중 오류가 발생했습니다." }, status: :internal_server_error
    end
  end
end