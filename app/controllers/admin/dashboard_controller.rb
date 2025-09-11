class Admin::DashboardController < ApplicationController
  before_action :authenticate_admin!
  
  def index
    # 통계 정보
    @total_users = User.count
    @pending_users = User.pending.count
    @approved_users = User.approved.count
    @on_hold_users = User.on_hold.count
    @total_pending_users = @pending_users
    
    # 연습실 예약 현황 (Practice)
    @practice_todays_reservations = Reservation.today.count
    @practice_active_reservations = Reservation.active.count
    
    # 보충수업 예약 현황 (Makeup)
    @makeup_todays_reservations = MakeupReservation.today.count
    @makeup_active_reservations = MakeupReservation.active.count
    
    # 전체 예약 현황 (연습실 + 보충수업)
    @total_todays_reservations = @practice_todays_reservations + @makeup_todays_reservations
    @total_active_reservations = @practice_active_reservations + @makeup_active_reservations
  end
  
  # 통합 회원 관리 페이지
  def users
    @tab = params[:tab] || 'approved'
    
    @pending_users = User.pending.to_a
    @on_hold_users = User.on_hold.to_a
    @approved_users = User.approved.to_a  # admin 포함 모든 승인된 사용자
    
    # 페널티가 있는 사용자 - 연습실과 보충수업 모두 포함
    practice_penalties = User.approved.select { |u| 
      penalty = u.current_month_penalty
      penalty.no_show_count > 0 || penalty.cancel_count > 0 || penalty.is_blocked
    }
    
    makeup_penalties = []
    begin
      makeup_users = MakeupUser.approved
      makeup_penalties = makeup_users.select do |user|
        penalty = user.current_month_penalty
        penalty.no_show_count > 0 || penalty.cancel_count > 0 || penalty.is_blocked
      end
    rescue => e
      Rails.logger.error "Error fetching makeup penalties: #{e.message}"
    end
    
    @users_with_penalties = practice_penalties + makeup_penalties
  end
  
  # AJAX를 위한 사용자 컨텐츠만 반환
  def users_content
    @tab = params[:tab] || 'approved'
    @page = (params[:page] || 1).to_i
    @per_page = 50
    
    # 데이터베이스에서 효율적으로 가져오기 (includes로 N+1 쿼리 방지)
    pending_users_query = User.pending.includes(:penalties)
    on_hold_users_query = User.on_hold.includes(:penalties)
    approved_users_query = User.approved.includes(:penalties)
    
    @pending_users = pending_users_query.map { |u| user_to_hash(u).merge('system' => 'practice') }
    @on_hold_users = on_hold_users_query.map { |u| user_to_hash(u).merge('system' => 'practice') }
    @approved_users = approved_users_query.map { |u| user_to_hash(u).merge('system' => 'practice', 'is_admin' => u.is_admin) }
    
    # 페널티가 있는 사용자 필터링 - 효율적으로 처리
    begin
      # 현재 월/연도
      current_month = Date.current.month
      current_year = Date.current.year
      
      # 연습실 페널티가 있는 사용자들
      practice_penalty_users = approved_users_query.joins(:penalties)
        .where(penalties: { 
          month: current_month, 
          year: current_year, 
          system_type: 'practice' 
        })
        .where('penalties.no_show_count > 0 OR penalties.cancel_count > 0 OR penalties.is_blocked = true')
        .includes(:penalties)
      
      practice_penalties = practice_penalty_users.map do |user|
        penalty = user.penalties.find { |p| p.month == current_month && p.year == current_year && p.system_type == 'practice' }
        user_to_hash(user).merge(
          'no_show_count' => penalty.no_show_count,
          'cancel_count' => penalty.cancel_count,
          'is_blocked' => penalty.is_blocked,
          'system' => 'practice'
        )
      end
      
      # 보충수업 페널티가 있는 사용자들
      makeup_penalty_users = approved_users_query.joins(:penalties)
        .where(penalties: { 
          month: current_month, 
          year: current_year, 
          system_type: 'makeup' 
        })
        .where('penalties.no_show_count > 0 OR penalties.cancel_count > 0 OR penalties.is_blocked = true')
        .includes(:penalties)
      
      makeup_penalties = makeup_penalty_users.map do |user|
        penalty = user.penalties.find { |p| p.month == current_month && p.year == current_year && p.system_type == 'makeup' }
        user_to_hash(user).merge(
          'no_show_count' => penalty.no_show_count,
          'cancel_count' => penalty.cancel_count,
          'is_blocked' => penalty.is_blocked,
          'system' => 'makeup'
        )
      end
      
      @users_with_penalties = practice_penalties + makeup_penalties
    rescue => e
      Rails.logger.error "Error fetching penalties: #{e.message}"
      @users_with_penalties = []
    end
    
    # 검색어가 있으면 전체 검색, 없으면 페이지네이션 적용
    search_query = params[:search]&.strip&.downcase
    
    if search_query.present?
      # 검색 시에는 페이지네이션 없이 전체 검색
      @pending_users = @pending_users.select { |u| 
        u['name']&.downcase&.include?(search_query) || 
        u['username']&.downcase&.include?(search_query) ||
        u['teacher']&.downcase&.include?(search_query)
      }
      @on_hold_users = @on_hold_users.select { |u| 
        u['name']&.downcase&.include?(search_query) || 
        u['username']&.downcase&.include?(search_query) ||
        u['teacher']&.downcase&.include?(search_query)
      }
      @approved_users = @approved_users.select { |u| 
        u['name']&.downcase&.include?(search_query) || 
        u['username']&.downcase&.include?(search_query) ||
        u['teacher']&.downcase&.include?(search_query)
      }
      @users_with_penalties = @users_with_penalties.select { |u| 
        u['name']&.downcase&.include?(search_query) || 
        u['username']&.downcase&.include?(search_query) ||
        u['teacher']&.downcase&.include?(search_query)
      }
    else
      # 검색어가 없으면 페이지네이션 적용
      case @tab
      when 'waiting'
        @total_count = @pending_users.size
        @total_pages = (@total_count.to_f / @per_page).ceil
        @pending_users = @pending_users[(@page - 1) * @per_page, @per_page] || []
      when 'hold'
        @total_count = @on_hold_users.size
        @total_pages = (@total_count.to_f / @per_page).ceil
        @on_hold_users = @on_hold_users[(@page - 1) * @per_page, @per_page] || []
      when 'penalty'
        @total_count = @users_with_penalties.size
        @total_pages = (@total_count.to_f / @per_page).ceil
        @users_with_penalties = @users_with_penalties[(@page - 1) * @per_page, @per_page] || []
      else # approved
        @total_count = @approved_users.size
        @total_pages = (@total_count.to_f / @per_page).ceil
        @approved_users = @approved_users[(@page - 1) * @per_page, @per_page] || []
      end
    end
    
    render partial: 'users_content'
  end
  
  # 사용자 정보 업데이트
  def update_practice_user_info
    Rails.logger.info "=== ADMIN UPDATE USER INFO ==="
    Rails.logger.info "Params: #{params.inspect}"
    
    user = User.find(params[:id])
    
    if user.update(phone: params[:phone])
      Rails.logger.info "Phone updated successfully"
      head :ok
    else
      Rails.logger.error "Failed to update phone"
      head :unprocessable_entity
    end
  end
  
  # 사용자 승인
  def approve_practice_user
    user = User.find(params[:id])
    if user.update(status: 'approved')
      # SMS 승인 알림 전송
      if user.phone.present?
        sms_service = SmsService.new
        result = sms_service.send_approval_notification(user.phone, user.name)
        
        if result[:success]
          Rails.logger.info "승인 알림 SMS 전송 성공: #{user.phone}"
        else
          Rails.logger.error "승인 알림 SMS 전송 실패: #{user.phone}"
        end
      end
      
      redirect_to admin_users_path(tab: 'pending'), notice: "사용자가 승인되었습니다."
    else
      redirect_to admin_users_path(tab: 'pending'), alert: "사용자 승인에 실패했습니다."
    end
  end
  
  # 사용자 거부/삭제
  def reject_practice_user
    user = User.find(params[:id])
    
    # 연관된 데이터 먼저 삭제
    begin
      user.penalties.destroy_all if user.penalties.exists?
      user.reservations.destroy_all if user.reservations.exists?
      user.makeup_lessons.destroy_all if user.makeup_lessons.exists?
      user.makeup_reservations.destroy_all if user.makeup_reservations.exists?
    rescue => e
      Rails.logger.error "Error deleting associated records: #{e.message}"
    end
    
    # 사용자 삭제
    user.delete # destroy 대신 delete 사용으로 콜백 스킵
    
    head :ok
  end
  
  # 사용자 보류
  def hold_practice_user
    user = User.find(params[:id])
    user.update(status: 'on_hold')
    redirect_to admin_users_path(tab: 'pending'), notice: "사용자가 보류되었습니다."
  end
  
  # 담당 선생님 업데이트
  def update_practice_teacher
    user = User.find(params[:id])
    if user.update(teacher: params[:teacher])
      head :ok
    else
      head :unprocessable_entity
    end
  end
  
  # 비밀번호 재설정
  def reset_practice_password
    user = User.find(params[:id])
    if user.update(password: params[:password])
      head :ok
    else
      head :unprocessable_entity
    end
  end
  
  # 페널티 초기화
  def reset_practice_penalty
    user = User.find(params[:id])
    penalty = user.current_month_penalty
    if penalty.update(no_show_count: 0, cancel_count: 0, is_blocked: false)
      head :ok
    else
      head :unprocessable_entity
    end
  end
  
  # 보충수업 관련 메서드들 (동일한 DB 사용)
  def makeup_users
    users
  end
  
  def approve_makeup_user
    approve_practice_user
  end
  
  def reject_makeup_user
    reject_practice_user
  end
  
  def hold_makeup_user
    hold_practice_user
  end
  
  def update_makeup_teacher
    update_practice_teacher
  end
  
  def reset_makeup_password
    reset_practice_password
  end
  
  def reset_makeup_penalty
    # 보충수업 시스템의 페널티 초기화 - MakeupUser 모델 사용
    user = MakeupUser.find(params[:id])
    penalty = user.current_month_penalty
    if penalty.update(no_show_count: 0, cancel_count: 0, is_blocked: false)
      head :ok
    else
      head :unprocessable_entity
    end
  end
  
  def update_makeup_user_info
    update_practice_user_info
  end
  
  # 기타 페이지들 (임시)
  def practice_users
    @tab = params[:tab] || 'approved'
    @pending_users = []
    @on_hold_users = []
    @approved_users = []
  end
  
  def reservations
    @reservations = []
  end
  
  def practice_penalties
    @users_with_penalties = []
  end
  
  def makeup_penalties
    @users_with_penalties = []
  end
  
  def update_reservation_status
    head :ok
  end
  
  def delete_reservation
    redirect_to admin_reservations_path, notice: "예약이 삭제되었습니다."
  end
  
  private
  
  # ApplicationController의 authenticate_admin! 사용하도록 제거
  
  def user_to_hash(user)
    # 기본 사용자 정보만 반환 (penalty 정보는 별도로 처리)
    {
      'id' => user.id,
      'username' => user.username,
      'name' => user.name,
      'email' => user.email,
      'phone' => user.phone,
      'teacher' => user.teacher,
      'status' => user.status,
      'created_at' => user.created_at.to_s,
      'online_verification_image' => user.online_verification_image,
      'no_show_count' => 0,  # 기본값
      'cancel_count' => 0,   # 기본값
      'is_blocked' => false  # 기본값
    }
  end
end