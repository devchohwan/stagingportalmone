class SessionsController < ApplicationController
  def new
  end

  def create
    # 데이터베이스에서 직접 사용자 찾기
    user = User.find_by(username: params[:username])
    
    if user && user.authenticate(params[:password])
      if user.active? || user.approved?
        # 세션에 사용자 ID 저장 (DB 중심)
        session[:current_user_id] = user.id
        
        # 관리자 대시보드 호환성을 위한 추가 세션 설정
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
        
        Rails.logger.info "=== 로그인 성공 ==="
        Rails.logger.info "로그인 사용자: #{user.username}"
        Rails.logger.info "사용자 ID: #{user.id}"
        Rails.logger.info "전화번호: #{user.phone}"
        
        if user.teacher?
          redirect_to teacher_dashboard_path
        elsif user.is_admin
          redirect_to admin_dashboard_path
        else
          redirect_to services_path
        end
      else
        flash.now[:alert] = '승인 대기 중인 계정입니다'
        render :new, status: :unprocessable_entity
      end
    else
      flash.now[:alert] = '아이디 또는 비밀번호가 잘못되었습니다'
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    session[:current_user_id] = nil
    session[:jwt_token] = nil
    session[:user] = nil
    redirect_to root_path, notice: "로그아웃 되었습니다"
  end
end