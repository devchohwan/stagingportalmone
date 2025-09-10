class Admin::ApiController < ApplicationController
  before_action :authenticate_admin!
  
  def lesson_content
    reservation = MakeupReservation.find(params[:id])
    
    render json: {
      success: true,
      user_name: reservation.user.name,
      date: reservation.start_time.strftime('%Y년 %m월 %d일'),
      time: "#{reservation.start_time.strftime('%H:%M')} - #{reservation.end_time.strftime('%H:%M')}",
      lesson_content: reservation.lesson_content
    }
  rescue ActiveRecord::RecordNotFound
    render json: { success: false, error: '예약을 찾을 수 없습니다.' }, status: :not_found
  end
end
