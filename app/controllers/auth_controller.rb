class AuthController < ApplicationController
  # No need for skip_before_action since ApplicationController doesn't have global before_action
  
  def transfer
    if params[:user_id].present?
      user = User.find_by(id: params[:user_id])
      if user
        # 세션 완전 복구
        session[:current_user_id] = user.id
        
        # 관리자 대시보드 호환성을 위한 추가 세션 설정 (sessions_controller와 동일)
        session[:jwt_token] = "dummy_token_#{user.id}"
        session[:user] = {
          'id' => user.id,
          'username' => user.username,
          'name' => user.name,
          'email' => user.email,
          'phone' => user.phone,
          'teacher' => user.teacher,
          'is_admin' => user.is_admin
        }
        
        Rails.logger.info "Session transferred back for user: #{user.id} (admin: #{user.is_admin}) from #{params[:from]}"
        redirect_to services_path
      else
        Rails.logger.error "User not found: #{params[:user_id]}"
        redirect_to login_path, alert: '사용자를 찾을 수 없습니다.'
      end
    else
      Rails.logger.error "No user_id provided in transfer"
      redirect_to login_path, alert: '잘못된 접근입니다.'
    end
  end
end