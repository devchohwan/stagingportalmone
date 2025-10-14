class MakeupPassController < ApplicationController
  before_action :require_login
  before_action :check_on_leave, except: [:index, :my_requests]

  def index
    # 메인 페이지
    @has_active_makeup = current_user.makeup_pass_requests.where(status: 'active', request_type: 'makeup').exists?

    # 이번 주에 이미 보강을 받았는지 확인
    last_completed_makeup = current_user.makeup_pass_requests
      .where(request_type: 'makeup', status: 'completed')
      .order(makeup_date: :desc)
      .first
    @has_completed_makeup_this_week = last_completed_makeup && last_completed_makeup.request_date >= Date.current
  end

  def reserve
    # 예약 페이지
    @date = params[:date] ? Date.parse(params[:date]) : Date.current
    @has_cancelled_makeup = current_user.has_cancelled_makeup_before_next_lesson?
    @next_lesson_datetime = current_user.next_lesson_datetime if @has_cancelled_makeup
    @remaining_passes = current_user.current_remaining_passes

    # AJAX 요청인 경우 달력만 렌더링
    if request.xhr?
      render partial: 'calendar', locals: { date: @date, selected_date: nil }
    end
  end

  def create_request
    request_type = params[:makeup_pass_request][:type]
    selected_date = Date.parse(params[:makeup_pass_request][:date])

    # 보강인 경우:
    #   - request_date: 이번 수업일 (연노랑 영역의 시작일)
    #   - makeup_date: 캘린더에서 선택한 날짜 (보강받을 날짜)
    # 패스인 경우:
    #   - request_date: 캘린더에서 선택한 날짜 (이번수업일)
    #   - 즉시 패스권 1회 차감, 수업횟수 1회 차감
    if request_type == 'makeup'
      # 이번 주에 이미 보강을 받았는지 확인 (결석 처리된 원래 수업일이 지나지 않았으면 불가)
      last_completed_makeup = current_user.makeup_pass_requests
        .where(request_type: 'makeup', status: 'completed')
        .order(makeup_date: :desc)
        .first

      if last_completed_makeup && last_completed_makeup.request_date >= Date.current
        redirect_to makeup_pass_reserve_path, alert: '이번 주 보강을 이미 받았습니다. 다음 정규 수업 후에 다시 신청해주세요.'
        return
      end

      # 이번 수업일 = 연노랑 영역의 시작일
      request_date = next_lesson_date

      makeup_pass_request = current_user.makeup_pass_requests.new(
        request_type: request_type,
        request_date: request_date,      # 이번 수업일 (취소할 원래 수업일)
        makeup_date: selected_date,      # 선택한 날짜 (보강받을 날짜)
        time_slot: params[:makeup_pass_request][:time_slot],
        teacher: params[:makeup_pass_request][:teacher],
        week_number: params[:makeup_pass_request][:week_number],
        content: params[:makeup_pass_request][:content],
        status: 'active'
      )
    else  # pass
      # 패스권 확인
      if current_user.current_remaining_passes <= 0
        redirect_to makeup_pass_reserve_path, alert: '남은 패스권이 없습니다.'
        return
      end

      makeup_pass_request = current_user.makeup_pass_requests.new(
        request_type: request_type,
        request_date: selected_date,     # 선택한 날짜 (이번수업일)
        makeup_date: nil,
        time_slot: nil,
        teacher: nil,
        week_number: params[:makeup_pass_request][:week_number],
        content: params[:makeup_pass_request][:content],
        status: 'completed'  # 패스는 즉시 완료 처리
      )

      if makeup_pass_request.save
        # 패스권 1회 차감
        current_user.remaining_passes = (current_user.remaining_passes || 0) - 1
        current_user.save!

        redirect_to makeup_pass_path, notice: '패스 신청이 완료되었습니다. 패스권이 차감되었습니다.'
        return
      else
        redirect_to makeup_pass_reserve_path, alert: "신청에 실패했습니다: #{makeup_pass_request.errors.full_messages.join(', ')}"
        return
      end
    end

    if makeup_pass_request.save
      redirect_to makeup_pass_path, notice: '신청이 완료되었습니다.'
    else
      redirect_to makeup_pass_reserve_path, alert: "신청에 실패했습니다: #{makeup_pass_request.errors.full_messages.join(', ')}"
    end
  end

  def change_request
    @request = current_user.makeup_pass_requests.find(params[:id])

    if @request.status != 'active'
      redirect_to makeup_pass_my_requests_path, alert: '변경할 수 없는 상태입니다.'
      return
    end

    @date = @request.makeup? && @request.makeup_date ? @request.makeup_date : @request.request_date
    @initial_type = @request.request_type  # 'makeup' or 'pass'
    @has_cancelled_makeup = current_user.has_cancelled_makeup_before_next_lesson?
    @next_lesson_datetime = current_user.next_lesson_datetime if @has_cancelled_makeup
  end

  def update_request
    @request = current_user.makeup_pass_requests.find(params[:id])

    if @request.status != 'active'
      redirect_to makeup_pass_my_requests_path, alert: '변경할 수 없는 상태입니다.'
      return
    end

    request_type = params[:makeup_pass_request][:type]
    selected_date = Date.parse(params[:makeup_pass_request][:date])

    if request_type == 'makeup'
      # 보강 변경 시: request_date는 원래 값 유지, makeup_date만 변경
      if @request.update(
        makeup_date: selected_date,           # 선택한 날짜 (보강받을 날짜)
        time_slot: params[:makeup_pass_request][:time_slot],
        teacher: params[:makeup_pass_request][:teacher],
        week_number: params[:makeup_pass_request][:week_number],
        content: params[:makeup_pass_request][:content]
      )
        redirect_to makeup_pass_my_requests_path, notice: '신청이 변경되었습니다.'
      else
        redirect_to change_makeup_pass_request_path(@request), alert: "변경에 실패했습니다: #{@request.errors.full_messages.join(', ')}"
      end
    else
      if @request.update(
        request_type: request_type,
        request_date: selected_date,          # 선택한 날짜 (이번수업일)
        makeup_date: nil,
        time_slot: nil,
        teacher: nil,
        week_number: params[:makeup_pass_request][:week_number],
        content: params[:makeup_pass_request][:content]
      )
        redirect_to makeup_pass_my_requests_path, notice: '신청이 변경되었습니다.'
      else
        redirect_to change_makeup_pass_request_path(@request), alert: "변경에 실패했습니다: #{@request.errors.full_messages.join(', ')}"
      end
    end
  end

  def cancel_request
    request = current_user.makeup_pass_requests.find(params[:id])

    if request.status != 'active'
      redirect_to makeup_pass_my_requests_path, alert: '취소할 수 없는 상태입니다.'
      return
    end

    # 보강 취소 시, 원래 자리가 꽉 찼는지 확인
    if request.makeup? && !request.can_return_to_original_slot?
      request.cancel!
      redirect_to makeup_pass_my_requests_path,
        alert: '보강이 취소되었습니다. 하지만 원래 자리가 이미 다른 학생으로 꽉 찼습니다. 다른 시간대로 보강을 다시 신청해주세요.'
      return
    end

    request.cancel!
    redirect_to makeup_pass_my_requests_path, notice: '신청이 취소되었습니다.'
  end

  def my_requests
    # 내 신청 목록
    @requests = current_user.makeup_pass_requests.recent
  end

  def available_time_slots
    # 선택한 날짜에 예약 가능한 시간대 반환
    date = Date.parse(params[:date])
    day_of_week = date.strftime('%a').downcase # 'mon', 'tue', etc.

    # 모든 시간대
    all_time_slots = ['13-14', '14-15', '15-16', '16-17', '17-18', '19-20', '20-21', '21-22']

    # 모든 선생님
    teachers = User::TEACHERS

    available_slots = []

    all_time_slots.each do |time_slot|
      # 이 시간대에 자리가 있는 선생님이 있는지 확인
      has_availability = teachers.any? do |teacher|
        count = TeacherSchedule.where(teacher: teacher, day: day_of_week, time_slot: time_slot).count
        count < 3
      end

      # 하나라도 자리가 있으면 시간대 추가
      if has_availability
        available_slots << {
          time_slot: time_slot,
          display_time: time_slot.split('-').first + ':00-' + time_slot.split('-').last + ':00'
        }
      end
    end

    render json: available_slots
  end

  def available_teachers
    # 선택한 날짜와 시간대에 예약 가능한 선생님 반환
    date = Date.parse(params[:date])
    time_slot = params[:time_slot]

    # 학생이 선택 가능한 선생님 목록
    teachers = Teacher.available_for_student(current_user.teacher)

    available_teachers = []

    teachers.each do |teacher|
      # 선생님 휴무일 체크
      next if Teacher.closed_on?(teacher, date)

      # 자리가 있는지 확인
      current_count = TeacherSchedule.current_count(date, time_slot, teacher)
      available_slots = TeacherSchedule.available_slots(date, time_slot, teacher)

      if available_slots > 0
        available_teachers << {
          teacher: teacher,
          current_count: current_count,
          available_slots: available_slots
        }
      end
    end

    render json: available_teachers
  end

  private

  def check_on_leave
    if current_user.on_leave?
      redirect_to makeup_pass_path, alert: '휴원중입니다. 복귀 후 만나요!'
    end
  end

  def require_login
    unless logged_in?
      redirect_to login_path, alert: '로그인이 필요합니다'
    end
  end

end
