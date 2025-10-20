class MakeupNotificationService
  def self.on_makeup_created(makeup_request)
    return unless makeup_request.teacher.present?

    teacher = User.find_by(teacher_name: makeup_request.teacher)
    return unless teacher&.sms_enabled && teacher.phone.present?

    user = makeup_request.user
    date = makeup_request.makeup_date&.strftime('%m/%d') || '미정'
    time = makeup_request.time_slot&.split('-')&.first || '미정'

    message = "[보강신청] #{user.name} #{date} #{time}"
    SmsService.new.send_message(teacher.phone, message)
  end

  def self.on_makeup_cancelled(makeup_request)
    return unless makeup_request.teacher.present?

    teacher = User.find_by(teacher_name: makeup_request.teacher)
    return unless teacher&.sms_enabled && teacher.phone.present?

    user = makeup_request.user
    date = makeup_request.makeup_date&.strftime('%m/%d') || '미정'
    time = makeup_request.time_slot&.split('-')&.first || '미정'

    message = "[보강취소] #{user.name} #{date} #{time}"
    SmsService.new.send_message(teacher.phone, message)
  end
end
