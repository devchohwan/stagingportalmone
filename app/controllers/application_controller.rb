class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern
  
  helper_method :current_user, :logged_in?, :user_signed_in?, :authenticate_user!
  
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
    unless current_user&.is_admin
      redirect_to services_path, alert: "권한이 없습니다"
    end
  end
end
