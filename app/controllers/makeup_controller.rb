class MakeupController < ApplicationController
  before_action :require_login
  before_action :set_reservation, only: [:show, :cancel]
  
  def index
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
    if current_user.blocked?
      flash[:alert] = '월 2회 이상 노쇼/취소하여 이용이 제한되었습니다'
      redirect_to makeup_path
      return
    end
    
    @reservation = MakeupReservation.new
    @date = params[:date] ? Date.parse(params[:date]) : Date.current
  end
  
  def create
    # 중복 예약 체크
    existing = current_user.makeup_reservations
                          .where(status: ['pending', 'active'])
                          .where('end_time > ?', Time.current)
                          .exists?
    
    if existing
      redirect_to makeup_new_path, alert: '이미 예약하셨습니다. 예약한 시간을 먼저 사용해주세요.'
      return
    end
    
    @reservation = current_user.makeup_reservations.build(reservation_params)
    @reservation.status = 'pending'  # 관리자 승인 대기 상태
    
    if @reservation.save
      redirect_to makeup_my_lessons_path, notice: '예약 신청이 완료되었습니다. 관리자 승인을 기다려주세요.'
    else
      flash[:alert] = @reservation.errors.full_messages.first || '예약을 처리할 수 없습니다.'
      redirect_to makeup_new_path
    end
  end
  
  def show
  end
  
  def cancel
    if @reservation.cancellable?
      @reservation.update(status: 'cancelled', cancelled_by: 'user')
      redirect_to makeup_my_lessons_path, notice: '예약이 취소되었습니다.'
    else
      redirect_to makeup_my_lessons_path, alert: '예약 시작 30분 전까지만 취소 가능합니다.'
    end
  end
  
  def my_lessons
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
    
    @all_rooms = MakeupRoom.order(:number).map do |room|
      {
        room: room,
        available: room.available_at?(start_time, end_time)
      }
    end
    
    render partial: 'available_rooms', locals: { rooms_data: @all_rooms }
  end
  
  private
  
  def set_reservation
    @reservation = current_user.makeup_reservations.find(params[:id])
  end
  
  def reservation_params
    params.require(:makeup_lesson).permit(:makeup_room_id, :start_time, :end_time)
  end
  
  def generate_time_slots(date)
    slots = []
    current_time = Time.current
    
    # 화, 수, 토, 일 제한 시간 (14:30, 15:30, 16:30, 19:30, 20:30)
    restricted_times = [1430, 1530, 1630, 1930, 2030]
    restricted_days = [0, 2, 3, 6]  # 0=일, 2=화, 3=수, 6=토
    
    # 화, 수, 토 21:30 추가 제한
    restricted_times_2130 = [2, 3, 6]  # 2=화, 3=수, 6=토
    
    # 14:30부터 21:30까지 30분 단위 (브레이크타임 제외)
    (14..21).each do |hour|
      [0, 30].each do |minute|
        # 14:00과 14:30 중에서 14:30부터 시작
        next if hour == 14 && minute == 0
        
        # 선택한 날짜의 특정 시간을 서울 타임존으로 생성
        time = Time.zone.parse("#{date.strftime('%Y-%m-%d')} #{hour.to_s.rjust(2, '0')}:#{minute.to_s.rjust(2, '0')}:00")
        
        # 브레이크타임 (17:30, 18:00, 18:30) 제외
        hour_minute = hour * 100 + minute
        next if hour_minute == 1730 || hour_minute == 1800 || hour_minute == 1830
        
        # 화, 수, 토, 일 특정 시간 제한
        if restricted_days.include?(date.wday) && restricted_times.include?(hour_minute)
          next
        end
        
        # 화, 수, 토 21:30 추가 제한
        if restricted_times_2130.include?(date.wday) && hour_minute == 2130
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
          disabled: is_past  # 비활성화 플래그 추가
        }
      end
    end
    
    slots
  end
end