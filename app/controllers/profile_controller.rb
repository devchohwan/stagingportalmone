class ProfileController < ApplicationController
  before_action :require_login
  
  def edit
    # 프로필 편집 페이지
    Rails.logger.info "=== Profile Edit Page ===" 
    Rails.logger.info "Current user: #{current_user.username}"
    Rails.logger.info "Current phone: #{current_user.phone}"
    
    @current_phone = current_user.phone
  end
  
  def update_password
    # 비밀번호 확인 검증
    if params[:password] != params[:password_confirmation]
      flash[:alert] = '새 비밀번호와 비밀번호 확인이 일치하지 않습니다.'
      redirect_to edit_profile_path and return
    end
    
    if params[:password].to_s.length < 6
      flash[:alert] = '새 비밀번호는 최소 6자 이상이어야 합니다.'
      redirect_to edit_profile_path and return
    end
    
    # 현재 비밀번호 확인
    unless current_user.authenticate(params[:current_password])
      flash[:alert] = '현재 비밀번호가 일치하지 않습니다.'
      redirect_to edit_profile_path and return
    end
    
    # 비밀번호 업데이트
    if current_user.update(password: params[:password])
      Rails.logger.info "Password changed successfully for user: #{current_user.username}"
      
      # 세션 유지
      flash[:profile_success] = '비밀번호가 성공적으로 변경되었습니다.'
      redirect_to services_path
    else
      flash[:alert] = '비밀번호 변경에 실패했습니다. 다시 시도해주세요.'
      redirect_to edit_profile_path
    end
  end
  
  def update_phone
    Rails.logger.info "=== UPDATE PHONE REQUEST ===" 
    Rails.logger.info "Current user: #{current_user.username}"
    Rails.logger.info "New phone: #{params[:phone]}"
    
    # 전화번호 형식 검증
    phone = params[:phone].gsub(/[^0-9]/, '')  # 숫자만 추출
    
    unless phone.match?(/\A(010|011|016|017|018|019)\d{7,8}\z/)
      flash[:alert] = '올바른 휴대폰 번호를 입력해주세요.'
      redirect_to edit_profile_path and return
    end
    
    # 전화번호 업데이트
    if current_user.update(phone: phone)
      Rails.logger.info "Phone updated successfully: #{phone}"
      
      flash[:profile_success] = '전화번호가 성공적으로 변경되었습니다.'
      redirect_to services_path
    else
      flash[:alert] = '전화번호 변경에 실패했습니다. 다시 시도해주세요.'
      redirect_to edit_profile_path
    end
  end
  
  private
  
  # ApplicationController의 require_login을 사용
end