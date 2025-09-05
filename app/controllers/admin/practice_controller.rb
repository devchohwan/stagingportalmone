class Admin::PracticeController < ApplicationController
  before_action :authenticate_admin!
  before_action :set_practice_api_headers
  
  def index
    # 통계 데이터 가져오기
    dashboard_response = HTTParty.get(
      "#{Rails.configuration.practice_url}/api/v1/admin/dashboard",
      headers: @api_headers
    )
    
    if dashboard_response.success?
      data = JSON.parse(dashboard_response.body)
      @pending_users = data['pending_users']
      @total_users = data['total_users']
      @todays_reservations = data['todays_reservations']
      @active_reservations = data['active_reservations']
    else
      @pending_users = 0
      @total_users = 0
      @todays_reservations = 0
      @active_reservations = 0
    end
  end
  
  def users
    @tab = params[:tab] || 'approved'
    
    # API 호출로 사용자 목록 가져오기
    users_response = HTTParty.get(
      "#{Rails.configuration.practice_url}/api/v1/admin/users",
      headers: @api_headers
    )
    
    if users_response.success?
      users = JSON.parse(users_response.body)['users']
      @pending_users = users.select { |u| u['status'] == 'pending' }
      @on_hold_users = users.select { |u| u['status'] == 'on_hold' }
      @approved_users = users.select { |u| u['status'] == 'approved' && !u['is_admin'] }
    else
      @pending_users = []
      @on_hold_users = []
      @approved_users = []
    end
  end
  
  def reservations
    # API 호출로 예약 목록 가져오기
    reservations_response = HTTParty.get(
      "#{Rails.configuration.practice_url}/api/v1/admin/reservations",
      headers: @api_headers
    )
    
    if reservations_response.success?
      @reservations = JSON.parse(reservations_response.body)['reservations']
    else
      @reservations = []
    end
  end
  
  def penalties
    # API 호출로 패널티 목록 가져오기
    penalties_response = HTTParty.get(
      "#{Rails.configuration.practice_url}/api/v1/admin/penalties",
      headers: @api_headers
    )
    
    if penalties_response.success?
      @users_with_penalties = JSON.parse(penalties_response.body)['users_with_penalties']
    else
      @users_with_penalties = []
    end
  end
  
  # 사용자 승인
  def approve_user
    response = HTTParty.patch(
      "#{Rails.configuration.practice_url}/api/v1/admin/users/#{params[:id]}/approve",
      headers: @api_headers
    )
    
    if response.success?
      redirect_back(fallback_location: admin_practice_users_path, notice: "사용자가 승인되었습니다.")
    else
      redirect_back(fallback_location: admin_practice_users_path, alert: "승인 실패")
    end
  end
  
  # 사용자 거부
  def reject_user
    response = HTTParty.patch(
      "#{Rails.configuration.practice_url}/api/v1/admin/users/#{params[:id]}/reject",
      headers: @api_headers
    )
    
    if response.success?
      redirect_back(fallback_location: admin_practice_users_path, notice: "사용자가 거부되었습니다.")
    else
      redirect_back(fallback_location: admin_practice_users_path, alert: "거부 실패")
    end
  end
  
  # 사용자 보류
  def hold_user
    response = HTTParty.patch(
      "#{Rails.configuration.practice_url}/api/v1/admin/users/#{params[:id]}/hold",
      headers: @api_headers
    )
    
    if response.success?
      redirect_back(fallback_location: admin_practice_users_path, notice: "사용자가 보류되었습니다.")
    else
      redirect_back(fallback_location: admin_practice_users_path, alert: "보류 실패")
    end
  end
  
  private
  
  def set_practice_api_headers
    @api_headers = {
      'Authorization' => "Bearer #{session[:jwt_token]}",
      'Content-Type' => 'application/json'
    }
  end
  
  def authenticate_admin!
    unless session[:user] && session[:user]['is_admin']
      redirect_to login_path, alert: "관리자 권한이 필요합니다"
    end
  end
end