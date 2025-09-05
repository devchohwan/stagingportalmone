class Admin::UsersController < ApplicationController
  before_action :authenticate_admin!
  before_action :set_user, only: [:approve, :reject, :hold, :destroy, :update_teacher]
  before_action :set_user_by_username, only: [:reset_password]
  
  def index
    @tab = params[:tab] || 'approved'
    @pending_users = User.pending
    @on_hold_users = User.on_hold
    @approved_users = User.approved.where(is_admin: false)
  end
  
  def approve
    @user.update(status: 'approved')
    redirect_back(fallback_location: admin_users_path, notice: "#{@user.name}님이 승인되었습니다.")
  end
  
  def reject
    @user.destroy
    redirect_back(fallback_location: admin_users_path, notice: "요청이 거부되었습니다.")
  end
  
  def hold
    @user.update(status: 'on_hold')
    redirect_back(fallback_location: admin_users_path, notice: "#{@user.name}님이 보류 상태로 변경되었습니다.")
  end
  
  def destroy
    if @user.is_admin?
      redirect_to admin_users_path, alert: "관리자 계정은 삭제할 수 없습니다."
    else
      @user.destroy
      redirect_to admin_users_path, notice: "#{@user.name}님의 계정이 삭제되었습니다."
    end
  end
  
  def reset_password
    if @user.update(password: params[:password])
      redirect_to admin_users_path, notice: "#{@user.name}님의 비밀번호가 변경되었습니다."
    else
      redirect_to admin_users_path, alert: "비밀번호 변경에 실패했습니다."
    end
  end
  
  def update_teacher
    if @user.update(teacher: params[:teacher])
      redirect_to admin_users_path, notice: "#{@user.name}님의 담당 선생님이 #{params[:teacher]}(으)로 변경되었습니다."
    else
      redirect_to admin_users_path, alert: "담당 선생님 변경에 실패했습니다."
    end
  end
  
  private
  
  def set_user
    @user = User.find(params[:id])
  end
  
  def set_user_by_username
    @user = User.find_by(username: params[:id])
  end
end