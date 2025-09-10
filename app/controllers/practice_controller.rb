class PracticeController < ApplicationController
  before_action :require_login
  before_action :set_reservation, only: [:cancel_reservation]
  
  def index
    # 현재 활성 예약 확인
    if logged_in?
      @current_reservation = current_user.reservations
        .where(status: 'active')
        .where('start_time > ?', Time.current)
        .first
    end
  end
  
  def reserve
    if current_user.blocked?
      flash[:alert] = '월 2회 이상 노쇼/취소하여 이용이 제한되었습니다'
      redirect_to practice_path
      return
    end
    
    @reservation = Reservation.new
    @date = params[:date] ? Date.parse(params[:date]) : Date.current
  end
  
  def create_reservation
    # 사용자 차단 상태 확인
    if current_user.blocked?
      redirect_to practice_path, alert: '월 2회 이상 노쇼/취소하여 이용이 제한되었습니다'
      return
    end
    
    @reservation = current_user.reservations.build(reservation_params)
    @reservation.status = 'active' # status 기본값 설정
    
    if @reservation.save
      redirect_to practice_my_reservations_path, notice: '예약이 완료되었습니다.'
    else
      # 실제 에러 메시지를 표시
      flash[:alert] = @reservation.errors.full_messages.join(', ')
      redirect_to practice_reserve_path
    end
  end
  
  def my_reservations
    @reservations = current_user.reservations.includes(:room)
    
    # 상태 필터링
    if params[:status].present?
      case params[:status]
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
  
  def cancel_reservation
    if @reservation.cancellable?
      # active 상태의 예약 취소 시 페널티 적용
      if @reservation.status == 'active'
        # 페널티 적용 - 취소 횟수 증가
        penalty = current_user.current_month_penalty
        penalty.increment!(:cancel_count)
        
        # 총 페널티 횟수 확인 (노쇼 + 취소)
        total_penalties = penalty.no_show_count + penalty.cancel_count
        
        # 2회 이상이면 차단
        if total_penalties >= 2
          penalty.update(is_blocked: true)
        end
      end
      
      @reservation.update(status: 'cancelled', cancelled_by: 'user')
      
      if @reservation.status_was == 'active'
        redirect_to practice_my_reservations_path, notice: '예약이 취소되었습니다. (페널티가 적용되었습니다)'
      else
        redirect_to practice_my_reservations_path, notice: '예약이 취소되었습니다.'
      end
    else
      redirect_to practice_my_reservations_path, alert: '예약 시작 30분 전까지만 취소 가능합니다.'
    end
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
    
    @all_rooms = Room.order(:number).map do |room|
      {
        room: room,
        available: room.available_at?(start_time, end_time)
      }
    end
    
    render partial: 'available_rooms', locals: { rooms_data: @all_rooms }
  end
  
  private
  
  def set_reservation
    @reservation = current_user.reservations.find(params[:id])
  end
  
  def reservation_params
    params.require(:reservation).permit(:room_id, :start_time, :end_time)
  end
  
  def generate_time_slots(date)
    slots = []
    current_time = Time.current
    
    # 13:00부터 21:30까지 30분 단위 (브레이크타임 제외)
    (13..21).each do |hour|
      [0, 30].each do |minute|
        # 선택한 날짜의 특정 시간을 서울 타임존으로 생성
        time = Time.zone.parse("#{date.strftime('%Y-%m-%d')} #{hour.to_s.rjust(2, '0')}:#{minute.to_s.rjust(2, '0')}:00")
        
        # 브레이크타임 (17:30, 18:00, 18:30) 제외
        hour_minute = hour * 100 + minute
        next if hour_minute == 1730 || hour_minute == 1800 || hour_minute == 1830
        
        # 과거 시간인지 체크
        is_past = time <= current_time
        
        slots << {
          time: time,
          display: time.strftime('%H:%M'),
          period: case hour
                  when 13..17 then '오후'
                  else '저녁'
                  end,
          disabled: is_past  # 비활성화 플래그 추가
        }
      end
    end
    
    slots
  end
end