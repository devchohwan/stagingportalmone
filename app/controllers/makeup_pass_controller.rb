class MakeupPassController < ApplicationController
  before_action :require_login
  before_action :check_on_leave, except: [:index, :my_requests]

  def index
    @enrollments = current_user.user_enrollments
      .where(is_paid: true, status: 'active')
      .where('remaining_lessons > 0')
    
    active_subjects = @enrollments.pluck(:subject).uniq
    has_both_subjects = (active_subjects.include?('클린') && active_subjects.include?('믹싱'))
    
    if has_both_subjects
      clean_enrollment = @enrollments.find_by(subject: '클린')
      mixing_enrollment = @enrollments.find_by(subject: '믹싱')
      
      clean_has_active = current_user.makeup_pass_requests
        .where(status: 'active', request_type: 'makeup', user_enrollment_id: clean_enrollment&.id)
        .exists?
      
      mixing_has_active = current_user.makeup_pass_requests
        .where(status: 'active', request_type: 'makeup', user_enrollment_id: mixing_enrollment&.id)
        .exists?
      
      @has_active_makeup = clean_has_active && mixing_has_active
    else
      @has_active_makeup = current_user.makeup_pass_requests
        .where(status: 'active', request_type: 'makeup')
        .exists?
    end

    last_completed_makeup = current_user.makeup_pass_requests
      .where(request_type: 'makeup', status: 'completed')
      .order(makeup_date: :desc)
      .first
    @has_completed_makeup_this_week = last_completed_makeup && last_completed_makeup.request_date >= Date.current
  end

  def reserve
    @enrollments = current_user.user_enrollments
      .where(is_paid: true, status: 'active')
      .where('remaining_lessons > 0')
      .order(first_lesson_date: :asc)
    
    @has_clean_enrollment = @enrollments.any? { |e| e.subject == '클린' }
    @clean_teachers_by_day = get_clean_teachers_by_day if @has_clean_enrollment
    
    @enrollment_id = params[:enrollment_id]&.to_i
    if @enrollment_id
      @selected_enrollment = @enrollments.find_by(id: @enrollment_id)
    end
    
    @date = params[:date] ? Date.parse(params[:date]) : Date.current
    @remaining_passes = current_user.current_remaining_passes

    if request.xhr?
      render partial: 'calendar', locals: { 
        date: @date, 
        selected_date: nil,
        enrollment: @selected_enrollment,
        clean_teachers_by_day: @clean_teachers_by_day
      }
    end
  end

  def create_request
    request_type = params[:makeup_pass_request][:type]
    selected_date = Date.parse(params[:makeup_pass_request][:date])
    enrollment_id = params[:makeup_pass_request][:user_enrollment_id]&.to_i

    enrollment = current_user.user_enrollments.find_by(id: enrollment_id) if enrollment_id
    unless enrollment
      redirect_to makeup_pass_reserve_path, alert: '과목을 선택해주세요.'
      return
    end

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

      # 이번 수업일 = 해당 enrollment의 다음 수업일 (결석 처리된 수업 포함)
      next_schedule = TeacherSchedule.where(
        user_enrollment_id: enrollment.id
      ).where('lesson_date >= ?', Date.current)
        .order(:lesson_date)
        .first
      
      request_date = next_schedule&.lesson_date || Date.current

      # 해당 날짜가 이미 결석 처리되어 있다면, 결석 취소 및 수업 횟수 복구
      if next_schedule && next_schedule.is_absent
        next_schedule.update!(is_absent: false)
        enrollment.increment!(:remaining_lessons)
        Rails.logger.info "보강 신청으로 결석 취소: #{current_user.name} / #{request_date} / 남은 수업: #{enrollment.remaining_lessons}"
      end

      makeup_pass_request = current_user.makeup_pass_requests.new(
        user_enrollment_id: enrollment.id,
        request_type: request_type,
        request_date: request_date,
        makeup_date: selected_date,
        time_slot: params[:makeup_pass_request][:time_slot],
        teacher: params[:makeup_pass_request][:teacher],
        week_number: params[:makeup_pass_request][:week_number],
        content: params[:makeup_pass_request][:content],
        status: 'active'
      )

      if enrollment.teacher == '지명' && enrollment.subject == '믹싱'
        week_number = enrollment.calculate_week_number(selected_date)
        group_makeup_slot_id = params[:makeup_pass_request][:group_makeup_slot_id]

        if group_makeup_slot_id.present?
          slot = GroupMakeupSlot.find_by(id: group_makeup_slot_id)
        else
          slot = GroupMakeupSlot.find_or_create_by!(
            lesson_date: selected_date,
            time_slot: params[:makeup_pass_request][:time_slot],
            week_number: week_number,
            subject: '믹싱'
          ) do |s|
            s.teacher = params[:makeup_pass_request][:teacher] || '오또'
            s.day = selected_date.strftime('%a').downcase
            s.max_capacity = 3
            s.status = 'active'
          end
        end

        makeup_pass_request.group_makeup_slot_id = slot.id
      end
    else
      if enrollment.remaining_passes <= 0
        redirect_to makeup_pass_reserve_path, alert: '해당 과목의 남은 패스권이 없습니다.'
        return
      end

      makeup_pass_request = current_user.makeup_pass_requests.new(
        user_enrollment_id: enrollment.id,
        request_type: request_type,
        request_date: selected_date,
        makeup_date: nil,
        time_slot: nil,
        teacher: nil,
        week_number: params[:makeup_pass_request][:week_number],
        content: params[:makeup_pass_request][:content],
        status: 'completed'
      )

      if makeup_pass_request.save
        enrollment.decrement!(:remaining_passes)
        Rails.logger.info "패스 신청: #{current_user.name} / #{enrollment.teacher} #{enrollment.subject} / 남은 패스권: #{enrollment.remaining_passes}"
        redirect_to makeup_pass_path, notice: '패스 신청이 완료되었습니다. 패스권이 차감되었습니다.'
        return
      else
        redirect_to makeup_pass_reserve_path, alert: "신청에 실패했습니다: #{makeup_pass_request.errors.full_messages.join(', ')}"
        return
      end
    end

    if makeup_pass_request.save
      MakeupNotificationService.on_makeup_created(makeup_pass_request)
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
    @initial_type = @request.request_type
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
    MakeupNotificationService.on_makeup_cancelled(request)
    redirect_to makeup_pass_my_requests_path, notice: '신청이 취소되었습니다.'
  end

  def my_requests
    # 내 신청 목록
    @requests = current_user.makeup_pass_requests.recent
  end

  def available_time_slots
    date = Date.parse(params[:date])
    enrollment_id = params[:enrollment_id]&.to_i

    if enrollment_id
      enrollment = current_user.user_enrollments.find_by(id: enrollment_id)
      if enrollment && enrollment.teacher == '지명' && enrollment.subject == '믹싱'
        week_number = enrollment.calculate_week_number(date)

        existing_slots = GroupMakeupSlot
          .where(lesson_date: date, subject: '믹싱', week_number: week_number)
          .map { |slot|
            current_count = MakeupPassRequest
              .where(group_makeup_slot_id: slot.id, status: ['active', 'completed'])
              .count
            
            next if current_count >= slot.max_capacity
            
            {
              time_slot: slot.time_slot,
              display_time: slot.display_time,
              teacher: slot.teacher,
              week_number: slot.week_number,
              current_count: current_count,
              max_capacity: slot.max_capacity,
              group_makeup_slot_id: slot.id
            }
          }.compact

        day_of_week = date.strftime('%a').downcase
        
        empty_slots = []
        if day_of_week == 'sat'
          teacher = '오또'
          all_time_slots = ['13-14', '14-15', '15-16', '16-17', '17-18', '19-20', '20-21', '21-22']
          
          all_time_slots.each do |time_slot|
            existing_group_slot = existing_slots.find { |s| s[:time_slot] == time_slot }
            next if existing_group_slot
            
            other_week_slots = GroupMakeupSlot
              .where(lesson_date: date, time_slot: time_slot, subject: '믹싱')
              .where.not(week_number: week_number)
            next if other_week_slots.exists?
            
            current_count = TeacherSchedule.where(
              teacher: teacher,
              day: day_of_week,
              time_slot: time_slot,
              lesson_date: date,
              is_on_leave: false,
              is_absent: false
            ).count
            
            makeup_count = MakeupPassRequest
              .where(status: 'active', request_type: 'makeup')
              .where(makeup_date: date, time_slot: time_slot, teacher: teacher)
              .where.not(group_makeup_slot_id: nil)
              .count
            
            regular_makeup_count = MakeupPassRequest
              .where(status: 'active', request_type: 'makeup')
              .where(makeup_date: date, time_slot: time_slot, teacher: teacher)
              .where(group_makeup_slot_id: nil)
              .count
            
            next if regular_makeup_count > 0
            
            total_count = current_count + makeup_count
            
            if total_count < 3
              empty_slots << {
                time_slot: time_slot,
                display_time: time_slot.split('-').first + ':00-' + time_slot.split('-').last + ':00',
                teacher: teacher,
                week_number: week_number,
                current_count: 0,
                max_capacity: 3,
                group_makeup_slot_id: nil
              }
            end
          end
        end

        all_slots = existing_slots + empty_slots
        all_slots.sort_by! { |s| s[:time_slot] }

        render json: all_slots
        return
      end
    end

    # 일반 보강 로직 (기존 코드)
    day_of_week = date.strftime('%a').downcase
    selected_teacher = params[:teacher]
    all_time_slots = ['13-14', '14-15', '15-16', '16-17', '17-18', '19-20', '20-21', '21-22']
    teachers = User::TEACHERS - ['온라인']
    available_slots = []

    if selected_teacher.present?
      teachers = [selected_teacher]
    end

    all_time_slots.each do |time_slot|
      teachers.each do |teacher|
        next if Teacher.closed_on?(teacher, date)

        if teacher == '오또'
          mixing_slots = GroupMakeupSlot.where(
            lesson_date: date,
            time_slot: time_slot,
            subject: '믹싱'
          )
          
          has_reservations = mixing_slots.any? do |slot|
            MakeupPassRequest.where(
              group_makeup_slot_id: slot.id,
              status: ['active', 'completed']
            ).exists?
          end
          
          next if has_reservations
        end

        current_count = TeacherSchedule.where(
          teacher: teacher,
          day: day_of_week,
          time_slot: time_slot,
          lesson_date: date,
          is_on_leave: false,
          is_absent: false
        ).count

        # 보강으로 빠진 학생 수 (원래 이 시간대에 있던 학생이 보강으로 이동)
        makeup_away_count = MakeupPassRequest
          .joins('INNER JOIN teacher_schedules ON makeup_pass_requests.user_id = teacher_schedules.user_id')
          .where('teacher_schedules.teacher = ?', teacher)
          .where('teacher_schedules.day = ?', day_of_week)
          .where('teacher_schedules.time_slot = ?', time_slot)
          .where('teacher_schedules.lesson_date = ?', date)
          .where('makeup_pass_requests.request_type = ?', 'makeup')
          .where('makeup_pass_requests.request_date = ?', date)
          .where('makeup_pass_requests.status IN (?)', ['active', 'completed'])
          .count

        # 이 시간대로 보강 오는 학생 수
        makeup_count = MakeupPassRequest
          .where(status: 'active', request_type: 'makeup')
          .where(makeup_date: date, time_slot: time_slot, teacher: teacher)
          .count

        # 실제 차지하는 자리 = 정규 수업 - 보강 빠짐 + 보강 오는 사람
        total_count = current_count - makeup_away_count + makeup_count

        if total_count < 3
          available_slots << {
            time_slot: time_slot,
            teacher: teacher,
            display_time: time_slot.split('-').first + ':00-' + time_slot.split('-').last + ':00',
            available_slots: 3 - total_count
          }
        end
      end
    end

    render json: available_slots
  rescue => e
    Rails.logger.error("시간대 조회 오류: #{e.message}")
    render json: { error: e.message }, status: :internal_server_error
  end

  def available_teachers
    date = Date.parse(params[:date])
    day_of_week = date.strftime('%a').downcase
    enrollment_id = params[:enrollment_id]&.to_i
    
    teachers = User::TEACHERS - ['온라인']
    
    if enrollment_id
      enrollment = current_user.user_enrollments.find_by(id: enrollment_id)
      if enrollment && enrollment.subject == '클린'
        teachers = teachers - ['지명', '도현']
      end
    end

    available_teachers = []

    teachers.each do |teacher|
      next if Teacher.closed_on?(teacher, date)

      all_time_slots = ['13-14', '14-15', '15-16', '16-17', '17-18', '19-20', '20-21', '21-22']
      has_any_slot = all_time_slots.any? do |time_slot|
        if teacher == '오또'
          mixing_slots = GroupMakeupSlot.where(
            lesson_date: date,
            time_slot: time_slot,
            subject: '믹싱'
          )
          
          has_reservations = mixing_slots.any? do |slot|
            MakeupPassRequest.where(
              group_makeup_slot_id: slot.id,
              status: ['active', 'completed']
            ).exists?
          end
          
          next false if has_reservations
        end

        current_count = TeacherSchedule.where(
          teacher: teacher, 
          day: day_of_week, 
          time_slot: time_slot,
          lesson_date: date,
          is_on_leave: false,
          is_absent: false
        ).count

        makeup_count = MakeupPassRequest
          .where(status: 'active', request_type: 'makeup')
          .where(makeup_date: date, time_slot: time_slot, teacher: teacher)
          .count

        (current_count + makeup_count) < 3
      end

      if has_any_slot
        available_teachers << {
          teacher: teacher
        }
      end
    end

    render json: available_teachers
  end

  def calculate_week
    enrollment_id = params[:enrollment_id]&.to_i
    date = Date.parse(params[:date])

    enrollment = current_user.user_enrollments.find_by(id: enrollment_id)
    unless enrollment
      render json: { error: '수강권을 찾을 수 없습니다.' }, status: :not_found
      return
    end

    week_number = enrollment.calculate_week_number(date)
    render json: { week_number: week_number }
  end

  def get_absent_weeks
    enrollment = current_user.user_enrollments.find(params[:enrollment_id])

    unless enrollment.teacher == '지명' && enrollment.subject == '믹싱'
      render json: []
      return
    end

    absent_schedules = TeacherSchedule
      .where(
        user_id: current_user.id,
        user_enrollment_id: enrollment.id,
        is_absent: true
      )

    absent_weeks = absent_schedules.map { |schedule|
      enrollment.calculate_week_number(schedule.lesson_date)
    }.uniq.compact.sort

    render json: absent_weeks
  rescue => e
    Rails.logger.error("결석 주차 조회 오류: #{e.message}")
    render json: { error: e.message }, status: :internal_server_error
  end

  def check_cancelled_makeup
    enrollment_id = params[:enrollment_id]
    has_cancelled = current_user.has_cancelled_makeup_before_next_lesson?(enrollment_id)
    next_lesson_datetime = current_user.next_lesson_datetime

    render json: {
      has_cancelled: has_cancelled,
      next_lesson_datetime: next_lesson_datetime&.strftime('%y.%m.%d %H:%M')
    }
  end

  private

  def get_clean_teachers_by_day
    clean_teachers = ['무성', '성균', '노네임', '로한', '범석', '두박', '오또']
    teachers_by_day = {}
    
    %w[mon tue wed thu fri sat sun].each do |day|
      teachers_by_day[day] = UserEnrollment
        .where(teacher: clean_teachers, day: day, is_paid: true)
        .where('remaining_lessons > 0')
        .pluck(:teacher)
        .uniq
    end
    
    teachers_by_day
  end

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
