class PitchController < ApplicationController
  before_action :require_login
  before_action :set_reservation, only: [:cancel_reservation]
  before_action :check_penalty, only: [:reserve, :create_reservation]

  def index
    @pending_count = current_user.pitch_reservations.pending.count
    @approved_count = current_user.pitch_reservations.approved
                      .where('start_time > ?', Time.current).count
    @penalty = current_user.pitch_penalty
  end

  def reserve
    @reservation = PitchReservation.new
    @date = params[:date] ? Date.parse(params[:date]) : Date.current

    if request.xhr?
      render partial: 'calendar', locals: { date: @date, selected_date: nil }
    end
  end

  def create_reservation
    reservation_date = Time.parse(reservation_params[:start_time]).to_date

    # 하루 한 번 제한 확인
    existing_today = current_user.pitch_reservations.active
                                 .where('DATE(start_time) = ?', reservation_date)
                                 .exists?

    if existing_today
      redirect_to pitch_reserve_path, alert: '하루에 한 번만 예약할 수 있습니다.'
      return
    end

    @reservation = current_user.pitch_reservations.build(reservation_params)
    @reservation.status = 'pending'

    if @reservation.save
      flash[:notice] = '예약 신청이 완료되었습니다. 관리자 승인을 기다려주세요.'
      redirect_to pitch_my_reservations_path
    else
      flash[:alert] = @reservation.errors.full_messages.join(', ')
      redirect_to pitch_reserve_path
    end
  end

  def my_reservations
    @reservations = current_user.pitch_reservations.includes(:pitch_room)

    # 상태 필터링
    if params[:status].present?
      @reservations = @reservations.where(status: params[:status])
    end

    # 날짜 필터링
    if params[:date].present?
      date = Date.parse(params[:date])
      @reservations = @reservations.where(start_time: date.beginning_of_day..date.end_of_day)
    end

    @reservations = @reservations.order(start_time: :desc)
  end

  def cancel_reservation
    if @reservation.can_cancel?
      @reservation.cancel!(current_user)
      flash[:notice] = '예약이 취소되었습니다.'
    else
      flash[:alert] = '승인된 예약은 취소할 수 없습니다.'
    end
    redirect_to pitch_my_reservations_path
  end

  # AJAX 엔드포인트
  def calendar
    @date = params[:date] ? Date.parse(params[:date]) : Date.current
    @selected_date = params[:selected_date] ? Date.parse(params[:selected_date]) : nil
    render partial: 'calendar', locals: { date: @date, selected_date: @selected_date }
  end

  def time_slots
    date = Date.parse(params[:date])
    @selected_date = date
    @time_slots = generate_time_slots(date)
    render partial: 'time_slots'
  end

  def available_seats
    start_time = Time.parse(params[:start_time])
    end_time = Time.parse(params[:end_time])
    @available_seats = PitchRoom.active.select do |seat|
      seat.available_at?(start_time, end_time)
    end
    render partial: 'available_seats'
  end

  private

  def set_reservation
    @reservation = current_user.pitch_reservations.find(params[:id])
  end

  def check_penalty
    if current_user.pitch_penalty.is_blocked?
      flash[:alert] = '페널티로 인해 음정수업 예약이 제한되었습니다.'
      redirect_to pitch_path
    end
  end

  def reservation_params
    params.require(:pitch_reservation).permit(:pitch_room_id, :start_time, :end_time, :notes, :week_number)
  end

  def generate_time_slots(date)
    slots = []
    start_hour = 13
    end_hour = 21

    (start_hour...end_hour).each do |hour|
      slot_start = date.to_time.change(hour: hour)
      slot_end = slot_start + 1.hour

      # 과거 시간은 제외
      next if slot_start < Time.current

      # 각 시간대별로 예약 가능한 좌석 수 계산
      available_seats = PitchRoom.active.count do |seat|
        seat.available_at?(slot_start, slot_end)
      end

      slots << {
        start_time: slot_start,
        end_time: slot_end,
        available_count: available_seats,
        is_available: available_seats > 0
      }
    end

    slots
  end
end