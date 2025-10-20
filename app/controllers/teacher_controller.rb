class TeacherController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_teacher!

  def dashboard
    @schedules = TeacherSchedule
      .where(teacher: current_user.teacher_name, lesson_date: Date.current)
      .order(:time_slot)

    @makeup_requests = MakeupPassRequest
      .where(teacher: current_user.teacher_name, status: 'active')
      .includes(:user)
      .order(created_at: :desc)
  end

  def toggle_sms
    current_user.update(sms_enabled: !current_user.sms_enabled)
    redirect_to teacher_dashboard_path, notice: "SMS 알림이 #{current_user.sms_enabled ? 'ON' : 'OFF'}되었습니다."
  end

  private

  def ensure_teacher!
    unless current_user.teacher?
      redirect_to root_path, alert: '선생님만 접근할 수 있습니다.'
    end
  end
end
