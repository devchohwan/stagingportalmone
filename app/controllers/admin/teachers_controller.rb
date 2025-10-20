class Admin::TeachersController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_admin!

  def index
    @teachers = User.where.not(teacher_name: nil).order(:teacher_name)
  end

  def update
    teacher = User.find(params[:id])
    if teacher.update(teacher_params)
      redirect_to admin_teachers_path, notice: '선생님 정보가 업데이트되었습니다.'
    else
      redirect_to admin_teachers_path, alert: '업데이트에 실패했습니다.'
    end
  end

  def toggle_sms
    teacher = User.find(params[:id])
    teacher.update(sms_enabled: !teacher.sms_enabled)
    redirect_to admin_teachers_path, notice: "#{teacher.name} SMS 알림이 #{teacher.sms_enabled ? 'ON' : 'OFF'}되었습니다."
  end

  def reset_password
    teacher = User.find(params[:id])
    new_password = params[:new_password]
    if new_password.present?
      teacher.password = new_password
      teacher.save
      redirect_to admin_teachers_path, notice: "#{teacher.name} 비밀번호가 재설정되었습니다."
    else
      redirect_to admin_teachers_path, alert: '비밀번호를 입력해주세요.'
    end
  end

  private

  def ensure_admin!
    unless current_user.is_admin
      redirect_to root_path, alert: '관리자만 접근할 수 있습니다.'
    end
  end

  def teacher_params
    params.require(:user).permit(:phone, :sms_enabled)
  end
end
