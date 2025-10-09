class MakeupController < ApplicationController
  before_action :require_login
  before_action :set_reservation, only: [:show, :cancel]
  
  def index
    # 시간 지난 active 예약들을 completed로 업데이트 (연습실과 동일한 로직)
    current_user.makeup_reservations.where(status: 'active').each(&:update_status_by_time!)
    
    @reservations = current_user.makeup_reservations.includes(:makeup_room)
    
    # 상태 필터링
    if params[:status].present?
      case params[:status]
      when 'pending'
        @reservations = @reservations.where(status: 'pending')
      when 'active'
        @reservations = @reservations.where(status: 'active').where('end_time > ?', Time.current)
      when 'completed'
        @reservations = @reservations.where('(status = ? OR (status = ? AND end_time <= ?))', 'completed', 'active', Time.current)
      when 'cancelled'
        @reservations = @reservations.where(status: 'cancelled')
      when 'no_show'
        @reservations = @reservations.where(status: 'no_show')
      end
    end
    
    # 날짜 필터링
    if params[:date].present?
      date = Date.parse(params[:date])
      start_of_day = date.beginning_of_day
      end_of_day = date.end_of_day
      @reservations = @reservations.where(start_time: start_of_day..end_of_day)
    end
    
    @reservations = @reservations.order(start_time: :desc)
  end
  
  def new
    if current_user.makeup_penalty.is_blocked?
      flash[:alert] = '월 2회 이상 노쇼/취소하여 보충수업 이용이 제한되었습니다'
      redirect_to makeup_path
      return
    end
    
    @reservation = MakeupReservation.new
    @date = params[:date] ? Date.parse(params[:date]) : Date.current
    
    # AJAX 요청인 경우 달력만 렌더링
    if request.xhr?
      render partial: 'calendar', locals: { date: @date, selected_date: nil }
    end
  end
  
  def create
    # === 디버그 로깅 시작 ===
    Rails.logger.info "=== MAKEUP CREATE DEBUG START ==="
    Rails.logger.info "Request ID: #{request.uuid}"
    Rails.logger.info "User: #{current_user.username} (ID: #{current_user.id})"
    Rails.logger.info "IP: #{request.remote_ip}"
    Rails.logger.info "User Agent: #{request.user_agent}"
    Rails.logger.info "Raw params: #{params.inspect}"

    # 파라미터 존재 여부 먼저 확인
    unless params[:makeup_lesson]
      Rails.logger.error "REJECTED: makeup_lesson params missing entirely"
      redirect_to makeup_new_path, alert: '예약 요청 형식이 올바르지 않습니다. 페이지를 새로고침 후 다시 시도해주세요.'
      return
    end

    Rails.logger.info "makeup_lesson params: #{params[:makeup_lesson].inspect}"

    # 개별 필드 검증
    begin
      Rails.logger.info "start_time: '#{reservation_params[:start_time]}' (blank?: #{reservation_params[:start_time].blank?})"
      Rails.logger.info "end_time: '#{reservation_params[:end_time]}' (blank?: #{reservation_params[:end_time].blank?})"
      Rails.logger.info "room_id: '#{reservation_params[:makeup_room_id]}' (blank?: #{reservation_params[:makeup_room_id].blank?})"
      Rails.logger.info "lesson_content: '#{reservation_params[:lesson_content]}' (blank?: #{reservation_params[:lesson_content].blank?})"
      Rails.logger.info "week_number: '#{reservation_params[:week_number]}' (blank?: #{reservation_params[:week_number].blank?})"
    rescue => e
      Rails.logger.error "Failed to parse reservation_params: #{e.message}"
    end

    # 파라미터 검증
    missing_fields = []
    missing_fields << '시작 시간' if reservation_params[:start_time].blank?
    missing_fields << '종료 시간' if reservation_params[:end_time].blank?
    missing_fields << '좌석' if reservation_params[:makeup_room_id].blank?
    missing_fields << '수업 내용' if reservation_params[:lesson_content].blank?
    missing_fields << '주차' if reservation_params[:week_number].blank?

    if missing_fields.any?
      error_msg = "다음 정보가 누락되었습니다: #{missing_fields.join(', ')}"
      Rails.logger.warn "REJECTED: #{error_msg}"
      redirect_to makeup_new_path, alert: error_msg
      return
    end

    # 중복 예약 체크
    existing_reservations = current_user.makeup_reservations
                                        .where(status: ['pending', 'active'])
                                        .where('end_time > ?', Time.current)

    Rails.logger.info "Existing active reservations count: #{existing_reservations.count}"
    existing_reservations.each do |r|
      Rails.logger.info "  - Reservation ##{r.id}: #{r.start_time} ~ #{r.end_time} (status: #{r.status})"
    end

    if existing_reservations.exists?
      Rails.logger.warn "REJECTED: User already has active reservation(s)"
      redirect_to makeup_new_path, alert: '이미 예약하셨습니다. 예약한 시간을 먼저 사용해주세요.'
      return
    end
    
    # 당일 예약 방지 체크
    start_time = Time.parse(reservation_params[:start_time])
    if start_time.to_date == Date.current
      redirect_to makeup_new_path, alert: '당일 예약은 불가능합니다. 다른 날짜를 선택해주세요.'
      return
    end
    
    # 하루 한 번 제한 확인
    reservation_date = start_time.to_date
    existing_today = current_user.makeup_reservations
                                 .where(status: ['pending', 'active'])
                                 .where('DATE(start_time) = ?', reservation_date)
                                 .exists?
    
    if existing_today
      redirect_to makeup_new_path, alert: '하루에 한 번만 보충수업을 예약할 수 있습니다.'
      return
    end
    
    @reservation = current_user.makeup_reservations.build(reservation_params)
    @reservation.status = 'pending'  # 관리자 승인 대기 상태
    
    # 동일 시간대에 이미 pending/active 예약이 있는지 체크
    existing = MakeupReservation
      .where(makeup_room_id: @reservation.makeup_room_id)
      .where(status: ['pending', 'active'])
      .where('(start_time < ? AND end_time > ?) OR (start_time < ? AND end_time > ?)',
             @reservation.end_time, @reservation.start_time, 
             @reservation.end_time, @reservation.start_time)
      .exists?
    
    if existing
      redirect_to makeup_new_path, alert: '이미 예약된 시간입니다. 다른 좌석이나 시간을 선택해주세요.'
      return
    end
    
    if @reservation.save
      Rails.logger.info "SUCCESS: Makeup reservation created ##{@reservation.id}"
      Rails.logger.info "=== MAKEUP CREATE DEBUG END ==="
      redirect_to makeup_my_lessons_path, notice: '예약 신청이 완료되었습니다. 관리자 승인을 기다려주세요.'
    else
      Rails.logger.error "FAILED: Reservation save failed - #{@reservation.errors.full_messages.join(', ')}"
      Rails.logger.info "=== MAKEUP CREATE DEBUG END ==="
      flash[:alert] = @reservation.errors.full_messages.first || '예약을 처리할 수 없습니다.'
      redirect_to makeup_new_path
    end
  end
  
  def show
  end
  
  def cancel
    Rails.logger.info "=== MAKEUP CANCEL ATTEMPT START ==="
    Rails.logger.info "Request ID: #{request.uuid}"
    Rails.logger.info "IP: #{request.remote_ip}"
    Rails.logger.info "User Agent: #{request.user_agent}"

    # 사용자 정보
    Rails.logger.info "Current User: #{current_user.username} (ID: #{current_user.id})"
    Rails.logger.info "User reservations count: #{current_user.makeup_reservations.count}"

    # 예약 찾기
    begin
      Rails.logger.info "Finding reservation ID: #{params[:id]}"
      @reservation = current_user.makeup_reservations.find(params[:id])
      Rails.logger.info "Reservation found: #{@reservation.inspect}"
    rescue ActiveRecord::RecordNotFound => e
      Rails.logger.error "Reservation not found: #{e.message}"
      redirect_to makeup_my_lessons_path, alert: '예약을 찾을 수 없습니다.'
      return
    end

    # 예약 상세 정보
    Rails.logger.info "Reservation ID: #{@reservation.id}"
    Rails.logger.info "Reservation User ID: #{@reservation.user_id}"
    Rails.logger.info "Reservation status: #{@reservation.status}"
    Rails.logger.info "Reservation start_time: #{@reservation.start_time}"
    Rails.logger.info "Reservation start_time class: #{@reservation.start_time.class}"

    # 시간 계산 상세
    Rails.logger.info "Current time: #{Time.current}"
    Rails.logger.info "Current time zone: #{Time.zone.name}"
    Rails.logger.info "30.minutes.from_now: #{30.minutes.from_now}"
    Rails.logger.info "Time difference (minutes): #{((@reservation.start_time - Time.current) / 60).round}"

    # cancellable? 조건 분해
    status_check = (@reservation.status == 'pending' || @reservation.status == 'active')
    time_check = @reservation.start_time > 30.minutes.from_now
    Rails.logger.info "Status check (pending or active): #{status_check}"
    Rails.logger.info "Time check (start > 30min from now): #{time_check}"
    Rails.logger.info "Cancellable? final: #{@reservation.cancellable?}"

    if @reservation.cancellable?
      Rails.logger.info "Attempting to update reservation..."

      # Update 전 상태
      Rails.logger.info "Before update - status: #{@reservation.status}"

      result = @reservation.update(
        status: 'cancelled',
        cancelled_by: 'user',
        cancellation_reason: params[:cancellation_reason]
      )

      Rails.logger.info "Update result: #{result}"

      if result
        Rails.logger.info "Update successful"
        Rails.logger.info "After update - status: #{@reservation.reload.status}"
        Rails.logger.info "Redirecting with success notice"
      else
        Rails.logger.error "Update failed!"
        Rails.logger.error "Errors: #{@reservation.errors.full_messages}"
        Rails.logger.error "Validation errors: #{@reservation.errors.to_json}"
      end

      redirect_to makeup_my_lessons_path, notice: '예약이 취소되었습니다.'
    else
      Rails.logger.info "Not cancellable - redirecting with alert"
      Rails.logger.info "Final status: #{@reservation.status}"
      Rails.logger.info "Final time check: #{@reservation.start_time} > #{30.minutes.from_now} = #{@reservation.start_time > 30.minutes.from_now}"
      redirect_to makeup_my_lessons_path, alert: '예약 시작 30분 전까지만 취소 가능합니다.'
    end

    Rails.logger.info "=== MAKEUP CANCEL ATTEMPT END ==="
  rescue => e
    Rails.logger.error "Unexpected error in cancel: #{e.class} - #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    redirect_to makeup_my_lessons_path, alert: '오류가 발생했습니다.'
  end
  
  def my_lessons
    # 시간 지난 active 예약들을 completed로 업데이트 (연습실과 동일한 로직)
    current_user.makeup_reservations.where(status: 'active').each(&:update_status_by_time!)
    
    @reservations = current_user.makeup_reservations.includes(:makeup_room)
    
    # 상태 필터링
    if params[:status].present?
      case params[:status]
      when 'pending'
        @reservations = @reservations.where(status: 'pending')
      when 'active'
        @reservations = @reservations.where(status: 'active').where('end_time > ?', Time.current)
      when 'completed'
        @reservations = @reservations.where('(status = ? OR (status = ? AND end_time <= ?))', 'completed', 'active', Time.current)
      when 'cancelled'
        @reservations = @reservations.where(status: 'cancelled')
      when 'no_show'
        @reservations = @reservations.where(status: 'no_show')
      end
    end
    
    # 날짜 필터링
    if params[:date].present?
      date = Date.parse(params[:date])
      start_of_day = date.beginning_of_day
      end_of_day = date.end_of_day
      @reservations = @reservations.where(start_time: start_of_day..end_of_day)
    end
    
    @reservations = @reservations.order(start_time: :desc)
  end
  
  def calendar
    @date = params[:date] ? Date.parse(params[:date]) : Date.current
    @selected_date = params[:selected_date] ? Date.parse(params[:selected_date]) : nil
    
    render partial: 'calendar', locals: { date: @date, selected_date: @selected_date }
  end
  
  def time_slots
    @date = Date.parse(params[:date])
    @time_slots = generate_time_slots(@date)
    
    render partial: 'time_slots', locals: { time_slots: @time_slots, date: @date }
  end
  
  def available_rooms
    start_time = Time.parse(params[:start_time])
    end_time = Time.parse(params[:end_time])
    
    Rails.logger.info "=== AVAILABLE ROOMS DEBUG ==="
    Rails.logger.info "Requested time: #{start_time} - #{end_time}"
    Rails.logger.info "Day of week: #{start_time.wday}"
    
    # 승인 대기 중인 예약을 조회 (시간 중복 검사)
    pending_reservations = MakeupReservation
      .where(status: 'pending')
      .where(
        '(start_time < ? AND end_time > ?) OR (start_time < ? AND end_time > ?) OR (start_time >= ? AND start_time < ?)',
        end_time, start_time,
        end_time, end_time,
        start_time, end_time
      )
    
    Rails.logger.info "Found pending reservations: #{pending_reservations.count}"
    pending_reservations.each do |res|
      Rails.logger.info "  - Room #{res.makeup_room_id}: #{res.start_time} - #{res.end_time}"
    end
    
    pending_room_ids = pending_reservations.pluck(:makeup_room_id)
    Rails.logger.info "Pending room IDs: #{pending_room_ids}"
    
    # 요일별 방 필터링 (9월 23일 이후부터 새로운 스케줄 적용)
    new_schedule_start_date = Date.new(2025, 9, 23)
    
    available_rooms = if [4, 5].include?(start_time.wday) && start_time.to_date >= new_schedule_start_date  # 목요일, 금요일 + 9월 23일 이후
      # 목/금: 1, 2, 3번 방 모두 사용 가능 (9월 23일 이후)
      MakeupRoom.where(number: [1, 2, 3]).order(:number)
    else
      # 다른 요일 또는 9월 23일 이전: 1, 2번 방만 사용 가능
      MakeupRoom.where(number: [1, 2]).order(:number)
    end
    
    @all_rooms = available_rooms.map do |room|
      is_pending = pending_room_ids.include?(room.id)
      is_available = room.available_at?(start_time, end_time)
      
      Rails.logger.info "Room #{room.number}: available=#{is_available}, pending=#{is_pending}"
      
      {
        room: room,
        available: is_available,
        pending: is_pending
      }
    end
    
    render partial: 'available_rooms', locals: { rooms_data: @all_rooms }
  end
  
  private
  
  def set_reservation
    @reservation = current_user.makeup_reservations.find(params[:id])
  end
  
  def reservation_params
    params.require(:makeup_lesson).permit(:makeup_room_id, :start_time, :end_time, :lesson_content, :week_number)
  end
  
  def generate_time_slots(date)
    slots = []
    current_time = Time.current
    
    # 요일별 허용 시간 설정
    # 9월 23일(다음주 월요일) 이후부터 새로운 스케줄 적용
    new_schedule_start_date = Date.new(2025, 9, 23)
    
    if [4, 5].include?(date.wday) && date >= new_schedule_start_date  # 목요일(4), 금요일(5) + 9월 23일 이후
      # 목/금: 15시, 16시, 17시, 19시, 20시, 21시 (정시만) - 9월 23일 이후
      allowed_hours = [15, 16, 17, 19, 20, 21]
      allowed_hours.each do |hour|
        time = Time.zone.parse("#{date.strftime('%Y-%m-%d')} #{hour.to_s.rjust(2, '0')}:00:00")
        
        # 과거 시간인지 체크
        is_past = time <= current_time
        
        slots << {
          time: time,
          display: time.strftime('%H:%M'),
          period: case hour
                  when 15..17 then '오후'
                  else '저녁'
                  end,
          disabled: is_past
        }
      end
    else
      # 다른 요일: 기존 로직 유지
      # 화, 수, 토, 일 제한 시간 (14:30, 15:30, 16:30, 19:30, 20:30)
      # 수요일 추가 제한 시간 (17:00, 19:00)
      restricted_times = [1430, 1530, 1630, 1930, 2030]
      wednesday_restricted_times = [1700, 1900]
      restricted_days = [0, 2, 3, 6]  # 0=일, 2=화, 3=수, 6=토
      
      # 14:30부터 21:30까지 30분 단위 (브레이크타임 제외)
      (14..21).each do |hour|
        [0, 30].each do |minute|
          # 14:00과 14:30 중에서 14:30부터 시작
          next if hour == 14 && minute == 0
          
          # 21:30은 목요일(4)과 금요일(5)만 허용 (이제 해당 없음)
          if hour == 21 && minute == 30
            next
          end
          
          # 선택한 날짜의 특정 시간을 서울 타임존으로 생성
          time = Time.zone.parse("#{date.strftime('%Y-%m-%d')} #{hour.to_s.rjust(2, '0')}:#{minute.to_s.rjust(2, '0')}:00")
          
          # 브레이크타임 (17:30, 18:00, 18:30) 제외
          hour_minute = hour * 100 + minute
          next if hour_minute == 1730 || hour_minute == 1800 || hour_minute == 1830
          
          # 화, 수, 토, 일 특정 시간 제한
          if restricted_days.include?(date.wday) && restricted_times.include?(hour_minute)
            next
          end

          # 수요일 추가 제한 시간 (17:00, 19:00)
          if date.wday == 3 && wednesday_restricted_times.include?(hour_minute)
            next
          end
          
          # 과거 시간인지 체크
          is_past = time <= current_time
          
          slots << {
            time: time,
            display: time.strftime('%H:%M'),
            period: case hour
                    when 14..17 then '오후'
                    else '저녁'
                    end,
            disabled: is_past
          }
        end
      end
    end
    
    slots
  end
end