class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern
  
  helper_method :current_user, :logged_in?, :user_signed_in?, :authenticate_user!
  
  before_action :update_reservation_statuses
  
  private
  
  def current_user
    @current_user ||= User.find_by(id: session[:current_user_id]) if session[:current_user_id]
  end
  
  def logged_in?
    !!current_user
  end
  
  def user_signed_in?
    logged_in?
  end
  
  def authenticate_user!
    require_login
  end
  
  def require_login
    unless logged_in?
      Rails.logger.info "No user session found, redirecting to login"
      redirect_to login_path, alert: "로그인이 필요합니다"
      return
    end
    
    Rails.logger.debug "User authenticated: #{current_user.id}"
  end
  
  def authenticate_admin!
    require_login
    return unless current_user
    
    unless current_user.is_admin
      redirect_to services_path, alert: "권한이 없습니다"
    end
  end
  
  def update_reservation_statuses
    # 모든 페이지 접속 시 과거 예약 상태 업데이트
    # active 또는 in_use 상태인 예약들 확인
    Reservation.where(status: ['active', 'in_use']).find_each do |reservation|
      reservation.update_status_by_time!
    end

    # 보강/패스 신청 상태도 업데이트
    MakeupPassRequest.update_statuses

    # 정규 수업 자동 차감 처리
    UserEnrollment.process_lesson_deductions

    # 현재 사용자의 패스 만료 체크
    if current_user.present?
      current_user.check_passes_expiration!
    end
  rescue => e
    # 에러가 발생해도 페이지 로딩은 계속
    Rails.logger.error "Failed to update reservation statuses: #{e.message}"
  end
end
