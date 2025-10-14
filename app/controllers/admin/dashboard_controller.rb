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

    # 결제 관리를 위한 선생님 및 휴무일 정보
    @teachers = User::TEACHERS - ['온라인']
    @teacher_holidays = Teacher::HOLIDAYS
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
        
        # 가장 최근의 취소/노쇼 예약 신청 시간 찾기
        latest_cancelled_reservation = user.reservations
          .where(status: ['cancelled', 'no_show'])
          .where('DATE(start_time) >= ?', Date.new(current_year, current_month, 1))
          .where('DATE(start_time) <= ?', Date.new(current_year, current_month, -1))
          .order(updated_at: :desc)
          .first
        
        reservation_time = latest_cancelled_reservation&.created_at
        
        user_to_hash(user).merge(
          'no_show_count' => penalty.no_show_count,
          'cancel_count' => penalty.cancel_count,
          'is_blocked' => penalty.is_blocked,
          'system' => 'practice',
          'penalty_created_at' => penalty.created_at,
          'reservation_time' => reservation_time
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
        
        # 가장 최근의 취소/노쇼 보충수업 예약 신청 시간 찾기
        latest_cancelled_makeup = user.makeup_reservations
          .where(status: ['cancelled', 'no_show'])
          .where('DATE(start_time) >= ?', Date.new(current_year, current_month, 1))
          .where('DATE(start_time) <= ?', Date.new(current_year, current_month, -1))
          .order(updated_at: :desc)
          .first
        
        reservation_time = latest_cancelled_makeup&.created_at
        
        user_to_hash(user).merge(
          'no_show_count' => penalty.no_show_count,
          'cancel_count' => penalty.cancel_count,
          'is_blocked' => penalty.is_blocked,
          'system' => 'makeup',
          'penalty_created_at' => penalty.created_at,
          'reservation_time' => reservation_time
        )
      end
      
      pitch_penalty_users = PitchPenalty.includes(:user)
        .where(month: current_month, year: current_year)
        .where('no_show_count > 0 OR cancel_count > 0 OR is_blocked = true')
      
      pitch_penalties = pitch_penalty_users.map do |pitch_penalty|
        user = pitch_penalty.user
        
        latest_cancelled_pitch = user.pitch_reservations
          .where(status: ['cancelled', 'no_show'])
          .where('DATE(start_time) >= ?', Date.new(current_year, current_month, 1))
          .where('DATE(start_time) <= ?', Date.new(current_year, current_month, -1))
          .order(updated_at: :desc)
          .first
        
        reservation_time = latest_cancelled_pitch&.created_at
        
        user_to_hash(user).merge(
          'no_show_count' => pitch_penalty.no_show_count,
          'cancel_count' => pitch_penalty.cancel_count,
          'is_blocked' => pitch_penalty.is_blocked,
          'system' => 'pitch',
          'penalty_id' => pitch_penalty.id,
          'penalty_created_at' => pitch_penalty.created_at,
          'reservation_time' => reservation_time
        )
      end
      
      @users_with_penalties = practice_penalties + makeup_penalties + pitch_penalties
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


  # 월별 결제 캘린더 데이터
  def payment_calendar_data
    year = params[:year].to_i
    month = params[:month].to_i

    # 해당 월의 시작일과 종료일
    start_date = Date.new(year, month, 1)
    end_date = start_date.end_of_month

    # 활성 회원만
    users = User.where(status: ['active', 'approved'])

    # 날짜별 결제 대상자 그룹핑
    payment_data = {}

    users.each do |user|
      # 첫 수업일이 있는 경우만 처리
      next unless user.first_lesson_date.present?

      # 마지막 결제 정보 가져오기
      last_payment = Payment.where(user_id: user.id).order(created_at: :desc).first

      # 결제 기간 계산 (기본 1개월)
      payment_period_days = if last_payment&.period.present?
        last_payment.period * 30
      else
        30 # 기본값
      end

      # 다음 결제일 = 첫 수업일 + 결제한 기간
      next_payment_date = user.first_lesson_date + payment_period_days.days

      # 해당 월에 결제일이 있는지 확인
      if next_payment_date >= start_date && next_payment_date <= end_date
        date_key = next_payment_date.strftime('%Y-%m-%d')
        payment_data[date_key] ||= []

        # 결제 완료 여부: 마지막 결제일이 다음 결제 예정일 이후인지 확인
        is_paid = user.last_payment_date.present? && user.last_payment_date >= next_payment_date

        payment_data[date_key] << {
          id: user.id,
          name: user.name,
          username: user.username,
          teacher: user.teacher,
          first_lesson_date: user.first_lesson_date,
          last_payment_date: user.last_payment_date,
          next_payment_date: next_payment_date,
          payment_period: last_payment&.period || 1,
          remaining_lessons: user.remaining_lessons || 0,
          is_paid: is_paid,
          days_overdue: is_paid ? 0 : (Date.current - next_payment_date).to_i
        }
      end
    end

    render json: {
      success: true,
      year: year,
      month: month,
      data: payment_data
    }
  rescue => e
    Rails.logger.error "결제 캘린더 데이터 오류: #{e.message}"
    render json: { success: false, message: e.message }, status: :internal_server_error
  end

  # 사용자 정보 업데이트
  def update_practice_user_info
    Rails.logger.info "=== ADMIN UPDATE USER INFO ==="
    Rails.logger.info "Params: #{params.inspect}"
    
    user = User.find(params[:id])
    
    # JSON 요청일 때는 params에서 직접 가져오고, 아니면 일반 params 사용
    phone_value = request.content_type =~ /json/ ? params[:phone] : params[:phone]
    
    if user.update(phone: phone_value)
      Rails.logger.info "Phone updated successfully for user #{user.id}: #{phone_value}"
      render json: { success: true }, status: :ok
    else
      Rails.logger.error "Failed to update phone: #{user.errors.full_messages}"
      render json: { success: false, errors: user.errors.full_messages }, status: :unprocessable_entity
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

    # destroy를 사용하여 모델의 dependent: :destroy 콜백으로 모든 연관 데이터 자동 삭제
    # User 모델에 정의된 연관관계: penalties, reservations, makeup_reservations,
    # makeup_pass_requests, pitch_reservations, pitch_penalties, payments, user_enrollments
    if user.destroy
      head :ok
    else
      Rails.logger.error "User deletion failed: #{user.errors.full_messages.join(', ')}"
      render json: { error: '회원 삭제에 실패했습니다.' }, status: :unprocessable_entity
    end
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
    Rails.logger.info "=== ADMIN UPDATE MAKEUP USER INFO ==="
    Rails.logger.info "Params: #{params.inspect}"
    
    user = MakeupUser.find(params[:id])
    
    # JSON 요청일 때는 params에서 직접 가져오고, 아니면 일반 params 사용
    phone_value = request.content_type =~ /json/ ? params[:phone] : params[:phone]
    
    if user.update(phone: phone_value)
      Rails.logger.info "Phone updated successfully for makeup user #{user.id}: #{phone_value}"
      render json: { success: true }, status: :ok
    else
      Rails.logger.error "Failed to update phone: #{user.errors.full_messages}"
      render json: { success: false, errors: user.errors.full_messages }, status: :unprocessable_entity
    end
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

  def pitch_penalties
    @penalties = PitchPenalty.includes(:user)
                       .where(month: Date.current.month, year: Date.current.year)
                       .order(created_at: :desc)

    # 검색 기능 (이름/아이디)
    if params[:search].present?
      search_term = "%#{params[:search]}%"
      @penalties = @penalties.joins(:user)
                            .where("users.name LIKE ? OR users.username LIKE ?", search_term, search_term)
    end

    # 차단된 회원만 보기
    if params[:blocked] == 'true'
      @penalties = @penalties.where(is_blocked: true)
    end

    render 'admin/pitch/penalties/index'
  end

  def reset_pitch_penalty
    @penalty = PitchPenalty.find(params[:id])
    if @penalty.update(penalty_count: 0, no_show_count: 0, cancel_count: 0, is_blocked: false)
      head :ok
    else
      head :unprocessable_entity
    end
  end

  def update_reservation_status
    head :ok
  end

  def delete_reservation
    redirect_to admin_reservations_path, notice: "예약이 삭제되었습니다."
  end

  # 수강생 검색 API (JSON)
  def search_students
    search_term = params[:search]&.strip&.downcase
    teacher = params[:teacher]&.strip
    page = (params[:page] || 1).to_i
    per_page = 10

    # 기본 쿼리: 승인된 사용자
    query = User.approved

    # 담당별 필터링
    if teacher.present?
      query = query.where(teacher: teacher)
    end

    # 검색어 필터링
    if search_term.present?
      query = query.where("LOWER(name) LIKE ? OR LOWER(username) LIKE ?", "%#{search_term}%", "%#{search_term}%")
    end

    # 전체 개수
    total_count = query.count
    total_pages = (total_count.to_f / per_page).ceil

    # 페이지네이션
    students = query.offset((page - 1) * per_page)
                    .limit(per_page)
                    .map do |user|
      {
        id: user.id,
        name: user.name,
        username: user.username,
        teacher: user.teacher || '미지정'
      }
    end

    render json: {
      students: students,
      page: page,
      per_page: per_page,
      total_count: total_count,
      total_pages: total_pages
    }
  end

  # 스케줄 저장 API
  def save_schedule
    teacher = params[:teacher]
    schedules = params[:schedules] # { day: { time_slot: [user_ids] } }

    if teacher.blank?
      render json: { success: false, message: '담당 정보가 누락되었습니다.' }, status: :bad_request
      return
    end

    begin
      # 3명 제한 검증
      if schedules.present?
        schedules.each do |day, time_slots|
          time_slots.each do |time_slot, user_ids|
            if user_ids.length > 3
              render json: { success: false, message: "한 타임에 최대 3명까지만 배정할 수 있습니다. (#{day} #{time_slot}: #{user_ids.length}명)" }, status: :unprocessable_entity
              return
            end
          end
        end
      end

      ActiveRecord::Base.transaction do
        # 해당 담당의 기존 스케줄 삭제
        TeacherSchedule.where(teacher: teacher).destroy_all

        # 새로운 스케줄 저장 (schedules가 비어있으면 모두 삭제만 됨)
        if schedules.present?
          schedules.each do |day, time_slots|
            time_slots.each do |time_slot, user_ids|
              user_ids.each do |user_id|
                TeacherSchedule.create!(
                  teacher: teacher,
                  day: day,
                  time_slot: time_slot,
                  user_id: user_id
                )
              end
            end
          end
        end
      end

      render json: { success: true, message: '스케줄이 저장되었습니다.' }
    rescue => e
      Rails.logger.error "스케줄 저장 오류: #{e.message}"
      render json: { success: false, message: '스케줄 저장 중 오류가 발생했습니다.' }, status: :internal_server_error
    end
  end

  # 스케줄 불러오기 API
  def load_schedule
    teacher = params[:teacher]
    week_offset = params[:week_offset].to_i || 0
    mode = params[:mode] || 'viewer' # 'viewer' 또는 'manager'

    if teacher.blank?
      render json: { success: false, message: '담당 정보가 필요합니다.' }, status: :bad_request
      return
    end

    # 현재 주차 계산 (일요일 시작)
    today = Date.current
    start_of_current_week = today.beginning_of_week(:sunday)
    target_week_start = start_of_current_week + week_offset.weeks
    target_week_end = target_week_start + 6.days

    Rails.logger.info "=== load_schedule 주차 계산 ==="
    Rails.logger.info "today: #{today}, week_offset: #{week_offset}"
    Rails.logger.info "target_week_start: #{target_week_start}, target_week_end: #{target_week_end}"

    schedules = TeacherSchedule.includes(:user).where(teacher: teacher)

    # { day: { time_slot: [{ id, name, username }] } } 형식으로 변환
    schedule_data = {}
    schedules.each do |schedule|
      day = schedule.day
      time_slot = schedule.time_slot
      user = schedule.user

      # user가 nil인 경우 skip (삭제된 회원)
      unless user
        Rails.logger.info "SKIP(user 없음): schedule_id=#{schedule.id}"
        next
      end

      # 이 주차에 보강/패스 신청이 있는지 확인
      day_index = { 'mon' => 1, 'tue' => 2, 'wed' => 3, 'thu' => 4, 'fri' => 5, 'sat' => 6, 'sun' => 0 }[day]
      target_date = target_week_start + day_index.days

      # UserEnrollment에서 휴원 상태 및 남은 수업 횟수 확인
      enrollment = UserEnrollment.find_by(
        user_id: user.id,
        teacher: teacher,
        day: day,
        time_slot: time_slot,
        is_paid: true
      )

      # enrollment가 없으면 skip
      unless enrollment
        Rails.logger.info "SKIP(enrollment 없음): #{user.name}"
        next
      end

      # 첫수업일 체크: enrollment의 first_lesson_date 기준
      if enrollment.first_lesson_date.present? && target_date < enrollment.first_lesson_date
        Rails.logger.info "SKIP(첫수업일 전): #{user.name} / target=#{target_date} < first=#{enrollment.first_lesson_date}"
        next
      end

      is_on_leave = enrollment.status == 'on_leave'

      # 휴원 상태일 때: 시간표에서 제거
      if is_on_leave
        Rails.logger.info "SKIP(휴원중): #{user.name} / remaining=#{enrollment.remaining_lessons}"
        next
      else
        # 활성 상태일 때: 첫수업일부터 수업 횟수만큼만 표시
        if enrollment.remaining_lessons <= 0
          Rails.logger.info "SKIP(활성 - 수업 횟수 소진): #{user.name} / remaining=#{enrollment.remaining_lessons}"
          next
        end

        # 첫수업일 기준으로 마지막 수업일 계산 (매주 1회)
        if enrollment.first_lesson_date.present? && enrollment.remaining_lessons > 0
          # 총 결제 수업 횟수 = Payment의 lessons 합계
          total_paid_lessons = Payment.where(user_id: user.id, teacher: teacher, subject: enrollment.subject).sum(:lessons)

          # Payment가 없으면 remaining_lessons를 기준으로 계산
          if total_paid_lessons == 0
            total_paid_lessons = enrollment.remaining_lessons
          end

          # 마지막 수업일 = 첫수업일 + (총 수업 횟수 - 1) * 7일
          last_lesson_date = enrollment.first_lesson_date + ((total_paid_lessons - 1) * 7).days

          if target_date > last_lesson_date
            Rails.logger.info "SKIP(활성 - 마지막수업 후): #{user.name} / target=#{target_date} > last=#{last_lesson_date} (#{total_paid_lessons}회)"
            next
          end
        end

        Rails.logger.info "표시됨(활성): #{user.name} / target=#{target_date} / remaining=#{enrollment.remaining_lessons}"
      end

      schedule_data[day] ||= {}
      schedule_data[day][time_slot] ||= []

      # 시간표 관리 모드에서는 보강/패스 영향 무시
      if mode == 'manager'
        # 시간표 관리: 모든 학생을 항상 정상 표시
        schedule_data[day][time_slot] << {
          id: user.id,
          name: user.name,
          username: user.username,
          teacher: user.teacher,
          is_on_leave: is_on_leave
        }
      else
        # 시간표 보기: 보강/패스 상태 반영
        # 이 날짜에 패스 신청이 있는지 확인
        pass_request = MakeupPassRequest.where(
          user_id: user.id,
          request_type: 'pass',
          request_date: target_date
        ).where(status: ['active', 'completed']).first

        # 이 날짜에 보강 신청(원래 자리에서 이동)이 있는지 확인
        makeup_away_request = MakeupPassRequest.where(
          user_id: user.id,
          request_type: 'makeup',
          request_date: target_date
        ).where(status: ['active', 'completed']).first

        # 이 날짜에 취소된 보강 신청이 있는지 확인 (결석 처리)
        cancelled_makeup_request = MakeupPassRequest.where(
          user_id: user.id,
          request_type: 'makeup',
          request_date: target_date,
          status: 'cancelled'
        ).first

        if pass_request
          # 패스인 경우: 회색으로 표시, "패스" 표시
          schedule_data[day][time_slot] << {
            id: user.id,
            name: user.name,
            username: user.username,
            teacher: user.teacher,
            schedule_id: schedule.id,
            is_pass: true,
            is_absent: schedule.is_absent,
            is_on_leave: is_on_leave
          }
        elsif makeup_away_request
          # 보강으로 이동하는 경우: 회색으로 표시, "→ 선생님" 표시
          schedule_data[day][time_slot] << {
            id: user.id,
            name: user.name,
            username: user.username,
            teacher: user.teacher,
            schedule_id: schedule.id,
            is_makeup_away: true,
            moved_to_teacher: makeup_away_request.teacher,
            makeup_request_id: makeup_away_request.id,
            is_absent: false,  # 보강 이동한 경우 결석이 아님
            is_on_leave: is_on_leave
          }
        elsif cancelled_makeup_request
          # 보강 취소한 경우: 회색으로 표시, "결석" 표시
          schedule_data[day][time_slot] << {
            id: user.id,
            name: user.name,
            username: user.username,
            teacher: user.teacher,
            schedule_id: schedule.id,
            is_absent: true,
            is_cancelled_makeup: true,
            cancelled_makeup_request_id: cancelled_makeup_request.id,
            original_date: target_date.to_s,
            is_on_leave: is_on_leave
          }
        else
          # 정상 출석 또는 휴원
          schedule_data[day][time_slot] << {
            id: user.id,
            name: user.name,
            username: user.username,
            teacher: user.teacher,
            schedule_id: schedule.id,
            is_absent: schedule.is_absent,
            is_on_leave: is_on_leave
          }
        end
      end
    end

    # 이 주차의 보강 신청을 추가 (다른 선생님한테서 이동해온 학생들)
    # 시간표 보기 모드에서만 표시
    if mode != 'manager'
      makeup_requests = MakeupPassRequest.includes(:user).where(
        request_type: 'makeup',
        teacher: teacher,
        makeup_date: target_week_start..target_week_end
      ).where(status: ['active', 'completed'])

      makeup_requests.each do |req|
        Rails.logger.info "보강 추가: #{req.user.name}, makeup_date: #{req.makeup_date}, wday: #{req.makeup_date.wday}"
        day_name = { 0 => 'sun', 1 => 'mon', 2 => 'tue', 3 => 'wed', 4 => 'thu', 5 => 'fri', 6 => 'sat' }[req.makeup_date.wday]
        time_slot = req.time_slot

        # 원래 선생님 찾기 (request_date의 요일로 UserEnrollment 조회)
        request_day_name = { 0 => 'sun', 1 => 'mon', 2 => 'tue', 3 => 'wed', 4 => 'thu', 5 => 'fri', 6 => 'sat' }[req.request_date.wday]
        original_enrollment = req.user.user_enrollments.find_by(
          day: request_day_name,
          is_paid: true
        )
        original_teacher_name = original_enrollment&.teacher || req.user.primary_teacher
        original_time_slot = original_enrollment&.time_slot

        # 원래 자기 시간인지 확인 (같은 요일, 같은 시간, 같은 선생님)
        is_original_schedule = (day_name == request_day_name) &&
                               (time_slot == original_time_slot) &&
                               (req.teacher == original_teacher_name)

        schedule_data[day_name] ||= {}
        schedule_data[day_name][time_slot] ||= []

        if is_original_schedule
          # 원래 자기 시간이면 정상 출석으로 표시 (이미 schedule_data에 있을 수 있으므로 중복 체크)
          existing_student = schedule_data[day_name][time_slot].find { |s| s[:id] == req.user.id }

          if existing_student
            # 이미 있으면 is_absent를 false로 변경 (결석 취소)
            existing_student[:is_absent] = false
            existing_student[:is_makeup_away] = false
            Rails.logger.info "보강 신청이 원래 시간과 동일 - 정상 출석으로 변경: #{req.user.name}"
          else
            # 없으면 정상 출석으로 추가
            schedule_data[day_name][time_slot] << {
              id: req.user.id,
              name: req.user.name,
              username: req.user.username,
              teacher: req.teacher,
              schedule_id: nil,
              is_absent: false,
              is_on_leave: false
            }
            Rails.logger.info "보강 신청이 원래 시간과 동일 - 정상 출석으로 추가: #{req.user.name}"
          end
        else
          # 다른 시간이면 보강으로 표시
          schedule_data[day_name][time_slot] << {
            id: req.user.id,
            name: req.user.name,
            username: req.user.username,
            teacher: req.teacher,
            is_makeup: true,
            original_teacher: original_teacher_name,
            week_number: req.week_number,
            makeup_request_id: req.id
          }
        end
      end
    end

    render json: { success: true, schedules: schedule_data, week_start: target_week_start.strftime('%Y-%m-%d'), week_end: target_week_end.strftime('%Y-%m-%d') }
  rescue => e
    Rails.logger.error "스케줄 불러오기 오류: #{e.message}"
    render json: { success: false, message: '스케줄을 불러오는 중 오류가 발생했습니다.' }, status: :internal_server_error
  end

  # 스케줄 변경 감지 (최근 N초간 변경 확인)
  def schedule_changes
    since = params[:since].to_i
    since_time = Time.at(since)

    # 최근 변경된 보강/패스 신청이 있는지 확인
    recent_changes = MakeupPassRequest.where('updated_at > ?', since_time).exists?

    render json: {
      changed: recent_changes,
      timestamp: Time.current.to_i
    }
  rescue => e
    Rails.logger.error "스케줄 변경 감지 오류: #{e.message}"
    render json: { changed: false, timestamp: Time.current.to_i }
  end

  # 보강 신청 상세 정보
  def makeup_request_info
    request_id = params[:id]
    request = MakeupPassRequest.find_by(id: request_id)

    if request
      status_map = {
        'active' => '활성',
        'cancelled' => '취소됨',
        'completed' => '완료'
      }

      # 원래 선생님 찾기 (request_date의 요일로 UserEnrollment 조회)
      request_day_name = { 0 => 'sun', 1 => 'mon', 2 => 'tue', 3 => 'wed', 4 => 'thu', 5 => 'fri', 6 => 'sat' }[request.request_date.wday]
      enrollment = request.user.user_enrollments.find_by(
        day: request_day_name,
        is_paid: true
      )

      render json: {
        success: true,
        request: {
          user_name: request.user.name,
          original_teacher: enrollment&.teacher || request.user.primary_teacher,
          request_date: request.request_date.strftime('%Y-%m-%d'),
          teacher: request.teacher,
          makeup_date: request.makeup_date&.strftime('%Y-%m-%d'),
          time_slot: request.time_slot,
          week_number: request.week_number,
          content: request.content,
          status_korean: status_map[request.status] || request.status
        }
      }
    else
      render json: { success: false, message: '보강 신청을 찾을 수 없습니다.' }
    end
  rescue => e
    Rails.logger.error "보강 신청 정보 조회 오류: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    render json: { success: false, message: e.message }
  end

  # 보강/패스 목록 불러오기 API
  def makeup_pass_requests
    request_type = params[:type] # 'makeup' or 'pass'

    requests = MakeupPassRequest.includes(:user).recent
    requests = requests.where(request_type: request_type) if request_type.present?

    render json: {
      success: true,
      requests: requests.map { |req|
        # 보강인 경우 보강 받을 날짜, 패스인 경우 패스할 날짜
        display_date = req.makeup? && req.makeup_date ? req.makeup_date : req.request_date

        {
          id: req.id,
          user_id: req.user_id,
          user_name: req.user.name,
          user_teacher: req.user.teacher,
          request_type: req.request_type,
          request_date: display_date.strftime('%Y년 %m월 %d일'),
          time_slot: req.time_slot,
          formatted_time: req.formatted_time,
          teacher: req.teacher,
          week_number: req.week_number,
          content: req.content,
          status: req.status,
          created_at: req.created_at.strftime('%Y년 %m월 %d일 %H:%M')
        }
      }
    }
  rescue => e
    Rails.logger.error "보강/패스 목록 불러오기 오류: #{e.message}"
    render json: { success: false, message: '목록을 불러오는 중 오류가 발생했습니다.' }, status: :internal_server_error
  end

  # 보강/패스 승인
  def approve_makeup_pass_request
    request = MakeupPassRequest.find(params[:id])
    request.approve!
    render json: { success: true, message: '승인되었습니다.' }
  rescue => e
    Rails.logger.error "보강/패스 승인 오류: #{e.message}"
    render json: { success: false, message: '승인 처리 중 오류가 발생했습니다.' }, status: :internal_server_error
  end

  # 보강/패스 거절
  def reject_makeup_pass_request
    request = MakeupPassRequest.find(params[:id])
    request.reject!
    render json: { success: true, message: '거절되었습니다.' }
  rescue => e
    Rails.logger.error "보강/패스 거절 오류: #{e.message}"
    render json: { success: false, message: '거절 처리 중 오류가 발생했습니다.' }, status: :internal_server_error
  end

  def delete_makeup_pass_request
    request = MakeupPassRequest.find(params[:id])
    request.destroy
    render json: { success: true, message: '삭제되었습니다.' }
  rescue => e
    Rails.logger.error "보강/패스 삭제 오류: #{e.message}"
    render json: { success: false, message: '삭제 처리 중 오류가 발생했습니다.' }, status: :internal_server_error
  end

  def create_payment
    # 다중 결제인지 확인
    if params[:payments].present?
      create_multi_payment
      return
    end

    # 기존 단일 결제 로직
    user = User.find(params[:user_id])

    # 첫수업 시작일시 파싱
    if params[:first_lesson_date].present? && params[:first_lesson_time].present?
      first_lesson_date = Date.parse(params[:first_lesson_date])
      time_slot = params[:first_lesson_time]
      day_of_week_num = first_lesson_date.wday

      # 요일 번호를 요일 문자열로 변환 (0=sun, 1=mon, 2=tue, ...)
      day_map = { 0 => 'sun', 1 => 'mon', 2 => 'tue', 3 => 'wed', 4 => 'thu', 5 => 'fri', 6 => 'sat' }
      day = day_map[day_of_week_num]

      # 해당 요일+시간에 스케줄 관리에서 현재 등록된 학생 수 확인
      current_count = TeacherSchedule.where(
        teacher: user.teacher,
        day: day,
        time_slot: time_slot
      ).count

      # 정원 3명 체크
      if current_count >= 3
        render json: { success: false, message: '스케줄이 다 차있습니다. 다른 시간을 골라주세요.' }, status: :unprocessable_entity
        return
      end

      # 종료일 계산 (첫수업일 + (수업횟수 * 7일) - 1일)
      # 예: 8회 수업 → 8주차까지 → 첫수업일 + 7*7 = 49일 후
      lessons_count = params[:new_total_lessons].to_i
      end_date = first_lesson_date + ((lessons_count - 1) * 7).days

      # 스케줄 관리에 자동 등록
      TeacherSchedule.create!(
        teacher: user.teacher,
        day: day,
        time_slot: time_slot,
        user_id: user.id,
        end_date: end_date
      )
    end

    # 남은 수업 횟수를 새로운 총 횟수로 직접 설정
    user.remaining_lessons = params[:new_total_lessons].to_i

    # 남은 패스 횟수 증가 (1개월당 1회)
    user.remaining_passes = (user.remaining_passes || 0) + params[:period].to_i

    # 마지막 결제일 업데이트
    payment_date = Date.parse(params[:payment_date])
    user.last_payment_date = payment_date

    # 첫수업 시작일 업데이트 (입력된 경우에만)
    if params[:first_lesson_date].present?
      user.first_lesson_date = Date.parse(params[:first_lesson_date])
    end

    # 패스 만료일 계산 (1개월 = 30일, 3개월 = 90일)
    days_to_add = params[:period].to_i * 30
    new_expire_date = payment_date + days_to_add.days

    # 기존 만료일보다 새 만료일이 더 나중이면 업데이트
    if user.passes_expire_date.nil? || new_expire_date > user.passes_expire_date
      user.passes_expire_date = new_expire_date
    end

    # Payment 모델에 결제 기록 저장 (히스토리용)
    Payment.create!(
      user_id: user.id,
      subject: params[:subject],
      period: params[:period],
      amount: params[:amount],
      payment_date: params[:payment_date],
      lessons: params[:lessons],
      first_lesson_date: params[:first_lesson_date].present? ? Date.parse(params[:first_lesson_date]) : nil,
      first_lesson_time: params[:first_lesson_time]
    )

    if user.save
      render json: { success: true, message: '결제 정보가 저장되었습니다.' }
    else
      render json: { success: false, message: user.errors.full_messages.join(', ') }, status: :unprocessable_entity
    end
  rescue => e
    Rails.logger.error "Payment creation error: #{e.message}"
    render json: { success: false, message: e.message }, status: :internal_server_error
  end

  def create_multi_payment
    Rails.logger.info "=== CREATE MULTI PAYMENT ==="
    Rails.logger.info "Params: #{params.to_unsafe_h.inspect}"

    user = User.find(params[:user_id])
    payment_date = Date.parse(params[:payment_date])

    # 과목별 가격 정의
    subject_prices = {
      '클린' => { 1 => 370000, 3 => 950000 },
      '언클린' => { 1 => 370000, 3 => 950000 },
      '믹싱' => { 1 => 280000, 4 => 990000 },
      '작곡' => { 1 => 350000, 3 => 950000 },
      '기타' => { 1 => 300000, 3 => 770000 }
    }

    ActiveRecord::Base.transaction do
      # 다중 결제 처리
      params[:payments].each do |payment_data|
        Rails.logger.info "=== Processing payment_data: #{payment_data.inspect}"

        enrollment = UserEnrollment.find(payment_data[:enrollment_id])
        period = payment_data[:period].to_i
        first_lesson_date = payment_data[:first_lesson_date].present? ? Date.parse(payment_data[:first_lesson_date]) : nil
        first_lesson_time = payment_data[:first_lesson_time]

        Rails.logger.info "=== Enrollment: id=#{enrollment.id}, day=#{enrollment.day}, time_slot=#{enrollment.time_slot}"
        Rails.logger.info "=== Payment data: period=#{period}, first_lesson_date=#{first_lesson_date}, first_lesson_time=#{first_lesson_time}"

        # 수업 횟수 계산 (주 1회 * 기간 주수)
        lessons = period * 4

        # UserEnrollment 업데이트
        Rails.logger.info "=== PAYMENT: Updating enrollment #{enrollment.id} ==="
        Rails.logger.info "Before: remaining_lessons=#{enrollment.remaining_lessons}, is_paid=#{enrollment.is_paid}"

        enrollment.remaining_lessons = (enrollment.remaining_lessons || 0) + lessons
        enrollment.is_paid = true  # 결제 완료 표시

        # 첫수업 날짜/시간 업데이트
        if first_lesson_date.present?
          enrollment.first_lesson_date = first_lesson_date
          user.first_lesson_date = first_lesson_date if user.first_lesson_date.nil?
        end

        # 종료일 계산
        days_to_add = period * 30
        new_end_date = (enrollment.end_date || payment_date) + days_to_add.days
        enrollment.end_date = new_end_date

        Rails.logger.info "After update: remaining_lessons=#{enrollment.remaining_lessons}, is_paid=#{enrollment.is_paid}"
        enrollment.save!
        Rails.logger.info "After save: remaining_lessons=#{enrollment.remaining_lessons}, is_paid=#{enrollment.is_paid}"

        # 스케줄 관리에 자동 등록 (첫수업 날짜/시간이 있는 경우)
        Rails.logger.info "=== Checking TeacherSchedule: first_lesson_date=#{first_lesson_date.present?}, day=#{enrollment.day.present?}, time_slot=#{enrollment.time_slot.present?}"

        if first_lesson_date.present? && enrollment.day.present? && enrollment.time_slot.present?
          # time_slot 형식 변환: "14:00" → "14-15"
          # enrollment.time_slot이 "14:00" 형식이면 "14-15" 형식으로 변환
          converted_time_slot = enrollment.time_slot
          if enrollment.time_slot =~ /^\d{2}:00$/
            hour = enrollment.time_slot.split(':')[0].to_i
            converted_time_slot = "#{hour}-#{hour + 1}"
            Rails.logger.info "=== Time slot converted: #{enrollment.time_slot} → #{converted_time_slot}"
          end

          # 기존 스케줄이 없는 경우에만 생성
          existing = TeacherSchedule.exists?(
            teacher: enrollment.teacher,
            day: enrollment.day,
            time_slot: converted_time_slot,
            user_id: user.id
          )

          Rails.logger.info "=== TeacherSchedule exists? #{existing}"

          unless existing
            # 종료일 계산 (첫수업일 + (수업횟수 - 1) * 7일)
            schedule_end_date = first_lesson_date + ((lessons - 1) * 7).days

            Rails.logger.info "=== Creating TeacherSchedule: teacher=#{enrollment.teacher}, day=#{enrollment.day}, time=#{converted_time_slot}, end=#{schedule_end_date}"

            TeacherSchedule.create!(
              teacher: enrollment.teacher,
              day: enrollment.day,
              time_slot: converted_time_slot,
              user_id: user.id,
              end_date: schedule_end_date
            )

            Rails.logger.info "=== TeacherSchedule created successfully"
          end
        end

        # 과목별 가격 가져오기
        amount = subject_prices.dig(enrollment.subject, period) || 0

        # Payment 기록 저장
        Payment.create!(
          user_id: user.id,
          enrollment_id: enrollment.id,
          subject: enrollment.subject,
          period: period,
          amount: amount,
          payment_date: payment_date,
          lessons: lessons,
          discount_items: params[:discount_items],
          discount_amount: params[:discount_amount],
          final_amount: params[:final_amount],
          first_lesson_date: first_lesson_date,
          first_lesson_time: first_lesson_time
        )
      end

      # User 레벨의 패스 업데이트 (전체 등록 과목 기준)
      total_lessons = params[:payments].sum { |p| p[:period].to_i * 4 }
      total_passes = params[:payments].size  # 과목당 1개

      user.remaining_passes = (user.remaining_passes || 0) + total_passes

      # 패스 만료일 연장
      max_period = params[:payments].map { |p| p[:period].to_i }.max
      days_to_add = max_period * 30
      new_expire_date = payment_date + days_to_add.days

      if user.passes_expire_date.nil? || new_expire_date > user.passes_expire_date
        user.passes_expire_date = new_expire_date
      end

      user.last_payment_date = payment_date
      user.save!

      render json: { success: true, message: '결제 정보가 저장되었습니다.' }
    end
  rescue => e
    Rails.logger.error "Multi-payment creation error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    render json: { success: false, message: e.message }, status: :internal_server_error
  end

  def update_user_status
    user = User.find(params[:id])
    new_status = params[:status]

    user.status = new_status
    if user.save
      message = new_status == 'on_leave' ? '휴원 처리되었습니다.' : '복귀 처리되었습니다.'
      render json: { success: true, message: message }
    else
      render json: { success: false, message: '상태 변경에 실패했습니다.' }, status: :unprocessable_entity
    end
  rescue => e
    render json: { success: false, message: e.message }, status: :internal_server_error
  end

  def toggle_all_enrollments
    user = User.find(params[:id])
    new_status = params[:status]

    # 모든 UserEnrollment의 상태 변경
    count = user.user_enrollments.update_all(status: new_status)

    message = new_status == 'on_leave' ? "#{count}개 과목이 휴원 처리되었습니다." : "#{count}개 과목이 복귀 처리되었습니다."
    render json: { success: true, message: message }
  rescue => e
    render json: { success: false, message: e.message }, status: :internal_server_error
  end

  def toggle_all_enrollments_auto
    user = User.find(params[:id])

    # 현재 상태 확인 (휴원 중인 과목이 있는지)
    has_on_leave = user.user_enrollments.exists?(status: 'on_leave')

    # 휴원 중인 과목이 하나라도 있으면 전부 복귀, 없으면 전부 휴원
    new_status = has_on_leave ? 'active' : 'on_leave'
    count = user.user_enrollments.update_all(status: new_status)

    message = new_status == 'on_leave' ? "#{count}개 과목을 휴원 처리했습니다." : "#{count}개 과목을 복귀 처리했습니다."
    render json: { success: true, message: message }
  rescue => e
    render json: { success: false, message: e.message }, status: :internal_server_error
  end

  def user_enrollments
    user = User.find(params[:user_id])
    # 미결제 항목만 가져오기
    enrollments = user.user_enrollments.where(is_paid: [false, nil]).order(created_at: :desc)

    enrollment_data = enrollments.map do |enrollment|
      {
        id: enrollment.id,
        teacher: enrollment.teacher,
        subject: enrollment.subject,
        day: enrollment.day,
        day_korean: enrollment.day_korean,
        time_slot: enrollment.time_slot,
        remaining_lessons: enrollment.remaining_lessons || 0,
        first_lesson_date: enrollment.first_lesson_date&.strftime('%Y년 %m월 %d일'),
        first_lesson_date_raw: enrollment.first_lesson_date&.strftime('%Y-%m-%d'),
        end_date: enrollment.end_date&.strftime('%Y년 %m월 %d일'),
        status: enrollment.status,
        display_name: "#{enrollment.subject} (#{enrollment.teacher}) - #{enrollment.day_korean} #{enrollment.time_display}"
      }
    end

    render json: {
      success: true,
      user_name: user.name,
      enrollments: enrollment_data
    }
  rescue => e
    render json: { success: false, message: e.message }, status: :internal_server_error
  end

  def create_user_enrollment
    user = User.find(params[:user_id])

    enrollment = user.user_enrollments.create!(
      teacher: params[:teacher],
      subject: params[:subject],
      day: params[:day],
      time_slot: params[:time_slot],
      first_lesson_date: params[:first_lesson_date],
      end_date: params[:end_date],
      remaining_lessons: params[:remaining_lessons] || 0,
      status: 'active'
    )

    render json: {
      success: true,
      message: '과목이 추가되었습니다.',
      enrollment: {
        id: enrollment.id,
        teacher: enrollment.teacher,
        subject: enrollment.subject,
        day: enrollment.day,
        day_korean: enrollment.day_korean,
        time_slot: enrollment.time_slot,
        first_lesson_date: enrollment.first_lesson_date,
        end_date: enrollment.end_date,
        remaining_lessons: enrollment.remaining_lessons
      }
    }
  rescue => e
    Rails.logger.error "Enrollment creation error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    render json: { success: false, message: e.message }, status: :internal_server_error
  end

  def delete_user_enrollment
    enrollment = UserEnrollment.find(params[:id])
    enrollment.destroy

    render json: { success: true, message: '과목이 삭제되었습니다.' }
  rescue => e
    Rails.logger.error "Enrollment deletion error: #{e.message}"
    render json: { success: false, message: e.message }, status: :internal_server_error
  end

  # 시간표 뷰어 페이지
  def schedule_viewer
    @teachers = User::TEACHERS - ['온라인']
    @selected_teacher = params[:teacher] || @teachers.first
  end

  # 시간표 관리 페이지
  def schedule_manager
    @teachers = User::TEACHERS - ['온라인']
    @selected_teacher = params[:teacher] || @teachers.first
  end
  
  # 시간표 뷰어 콘텐츠 (AJAX)
  def schedule_viewer_content
    @teachers = User::TEACHERS - ['온라인']
    @selected_teacher = params[:teacher] || @teachers.first
    @teacher_holidays = Teacher::HOLIDAYS
    render partial: 'admin/dashboard/schedule_viewer_content', layout: false
  end
  
  # 시간표 관리 콘텐츠 (AJAX)
  def schedule_manager_content
    @teachers = User::TEACHERS - ['온라인']
    @selected_teacher = params[:teacher] || @teachers.first
    @teacher_holidays = Teacher::HOLIDAYS
    render partial: 'admin/dashboard/schedule_manager_content', layout: false
  end

  def teacher_available_slots
    teacher = params[:teacher]

    # TeacherSchedule에서 해당 선생님의 모든 시간표 가져오기 (중복 제거)
    schedules = TeacherSchedule.where(teacher: teacher)
                                .select(:day, :time_slot)
                                .distinct
                                .order(:day, :time_slot)

    slots = schedules.map do |schedule|
      {
        day: schedule.day,
        time_slot: schedule.time_slot
      }
    end

    render json: {
      success: true,
      slots: slots
    }
  rescue => e
    Rails.logger.error "Teacher slots error: #{e.message}"
    render json: { success: false, message: e.message }, status: :internal_server_error
  end

  def payment_calendar
    teacher = params[:teacher]
    user_id = params[:user_id]
    date = Date.parse(params[:date])

    render partial: 'admin/dashboard/payment_calendar',
           locals: { date: date, teacher: teacher, row_id: user_id }
  end

  # 결제관리 콘텐츠 (AJAX)
  def payments_content
    users = User.order(:name)
    @users = users.map do |user|
      last_payment = Payment.where(user_id: user.id).order(payment_date: :desc).first
      {
        'id' => user.id,
        'name' => user.name,
        'username' => user.username,
        'teacher' => user.teacher,
        'status' => user.status,
        'last_payment_date' => last_payment&.payment_date
      }
    end
    @page = 1
    @total_pages = 1
    @teachers = User::TEACHERS - ['온라인']
    @teacher_holidays = Teacher::HOLIDAYS

    # 결제 캘린더용 데이터
    @payment_calendar_data = calculate_payment_calendar_data

    render partial: 'admin/dashboard/payments_content', layout: false
  end

  # 결제 예정일별 회원 목록 계산
  def calculate_payment_calendar_data
    payment_schedule = Hash.new { |h, k| h[k] = [] }

    UserEnrollment.where(is_paid: true, status: 'active').each do |enrollment|
      next_date = enrollment.next_payment_date
      next unless next_date

      payment_schedule[next_date] << {
        user_id: enrollment.user_id,
        user_name: enrollment.user.name,
        subject: enrollment.subject,
        teacher: enrollment.teacher,
        enrollment_id: enrollment.id
      }
    end

    payment_schedule
  end

  # 회원 정보 조회 (결제용)
  def get_user
    user = User.find(params[:id])
    render json: {
      id: user.id,
      name: user.name,
      username: user.username,
      teacher: user.teacher,
      remaining_lessons: user.remaining_lessons || 0,
      remaining_passes: user.remaining_passes || 0
    }
  rescue ActiveRecord::RecordNotFound
    render json: { error: '회원을 찾을 수 없습니다.' }, status: :not_found
  end

  # 결제 처리
  def process_payment
    user_id = params[:user_id]
    enrollments = params[:enrollments] || []
    payment_date = Date.parse(params[:payment_date])
    discounts = params[:discounts] || []
    total_price = params[:total_price].to_i
    discount_amount = params[:discount_amount].to_i
    final_price = params[:final_price].to_i

    user = User.find(user_id)

    ActiveRecord::Base.transaction do
      enrollments.each do |enrollment|
        first_lesson_date = enrollment['first_lesson_date'].present? ? Date.parse(enrollment['first_lesson_date']) : nil
        
        payment = Payment.create!(
          user_id: user_id,
          payment_date: payment_date,
          amount: enrollment['price'],
          discount_amount: discount_amount / enrollments.length,
          subject: enrollment['subject'],
          teacher: enrollment['teacher'],
          months: enrollment['months'],
          lessons: enrollment['lessons'],
          first_lesson_date: first_lesson_date,
          first_lesson_time: enrollment['time_slot'],
          discounts: discounts.join(',')
        )

        # day_of_week (숫자)를 day (문자열)로 변환
        day_mapping = { 0 => 'sun', 1 => 'mon', 2 => 'tue', 3 => 'wed', 4 => 'thu', 5 => 'fri', 6 => 'sat' }
        day_string = day_mapping[enrollment['day_of_week']]

        # end_date 파싱
        end_date = enrollment['end_date'].present? ? Date.parse(enrollment['end_date']) : nil

        # UserEnrollment 생성
        user_enrollment = UserEnrollment.create!(
          user_id: user_id,
          teacher: enrollment['teacher'],
          subject: enrollment['subject'],
          day: day_string,
          time_slot: enrollment['time_slot'],
          remaining_lessons: enrollment['lessons'],
          first_lesson_date: first_lesson_date,
          end_date: end_date,
          status: 'active',
          is_paid: true
        )

        # TeacherSchedule 등록 (중복 체크)
        existing_schedule = TeacherSchedule.find_by(
          teacher: enrollment['teacher'],
          day: day_string,
          time_slot: enrollment['time_slot'],
          user_id: user_id
        )

        if existing_schedule
          # 기존 스케줄이 있으면 end_date 업데이트 (더 늦은 날짜로)
          new_end_date = Date.parse(enrollment['end_date'])
          if existing_schedule.end_date.nil? || new_end_date > existing_schedule.end_date
            existing_schedule.update!(end_date: new_end_date)
          end
        else
          # 새 스케줄 생성
          TeacherSchedule.create!(
            teacher: enrollment['teacher'],
            day: day_string,
            time_slot: enrollment['time_slot'],
            user_id: user_id,
            end_date: enrollment['end_date']
          )
        end

        # User의 remaining_lessons와 remaining_passes 업데이트
        current_lessons = user.remaining_lessons || 0
        current_passes = user.remaining_passes || 0
        user.update!(
          remaining_lessons: current_lessons + enrollment['lessons'],
          remaining_passes: current_passes + enrollment['months']
        )
      end
    end

    render json: { success: true }
  rescue => e
    Rails.logger.error "Payment processing error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    render json: { success: false, error: e.message }, status: :unprocessable_entity
  end

  # 결제 이력 조회
  def payment_history
    user = User.find(params[:user_id])
    payments = Payment.where(user_id: user.id).order(payment_date: :desc)

    payment_list = payments.map do |payment|
      {
        payment_date: payment.payment_date.strftime('%Y.%m.%d'),
        subject: payment.subject,
        teacher: payment.teacher,
        months: payment.months,
        lessons: payment.lessons,
        amount: payment.amount,
        discount_amount: payment.discount_amount || 0,
        first_lesson_date: payment.first_lesson_date&.strftime('%Y.%m.%d'),
        first_lesson_time: payment.first_lesson_time
      }
    end

    render json: {
      user_name: user.name,
      payments: payment_list
    }
  rescue ActiveRecord::RecordNotFound
    render json: { error: '회원을 찾을 수 없습니다.' }, status: :not_found
  end

  # 선생님별 시간표 현황 조회 (휴원 해제용)
  def get_teacher_schedule_availability
    teacher = params[:teacher]

    # 요일별, 시간대별 현재 인원 계산
    days = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun']
    time_slots = ['13-14', '14-15', '15-16', '16-17', '17-18', '19-20', '20-21', '21-22']

    availability = {}
    days.each do |day|
      availability[day] = {}
      time_slots.each do |time_slot|
        # 현재 이 시간대에 등록된 활성 회원 수
        count = UserEnrollment.where(
          teacher: teacher,
          day: day,
          time_slot: time_slot,
          status: 'active',
          is_paid: true
        ).where('remaining_lessons > 0').count

        availability[day][time_slot] = {
          current: count,
          max: 3,
          available: count < 3
        }
      end
    end

    # 선생님 휴무일
    teacher_holidays = Teacher::HOLIDAYS[teacher] || []

    render json: {
      success: true,
      availability: availability,
      holidays: teacher_holidays
    }
  rescue => e
    render json: { success: false, error: e.message }, status: :unprocessable_entity
  end

  # 수강 등록 상태 토글
  def toggle_enrollment_status
    enrollment = UserEnrollment.find(params[:id])
    old_status = enrollment.status
    new_status = params[:status]

    ActiveRecord::Base.transaction do
      # 휴원 해제 시 (on_leave -> active) end_date 재계산 및 시간표 이동
      if old_status == 'on_leave' && new_status == 'active'
        new_day = params[:day]
        new_time_slot = params[:time_slot]
        new_teacher = params[:teacher] || enrollment.teacher
        new_first_lesson_date = params[:first_lesson_date].present? ? Date.parse(params[:first_lesson_date]) : nil

        # 남은 수업 횟수만큼 주 단위로 end_date 계산
        weeks_remaining = enrollment.remaining_lessons
        new_end_date = new_first_lesson_date ? new_first_lesson_date + (weeks_remaining - 1).weeks : Date.current + weeks_remaining.weeks

        # 기존 TeacherSchedule 찾기
        old_schedule = TeacherSchedule.find_by(
          user_id: enrollment.user_id,
          teacher: enrollment.teacher,
          day: enrollment.day,
          time_slot: enrollment.time_slot
        )

        # UserEnrollment 업데이트
        enrollment.update!(
          status: new_status,
          teacher: new_teacher,
          day: new_day,
          time_slot: new_time_slot,
          first_lesson_date: new_first_lesson_date || enrollment.first_lesson_date,
          end_date: new_end_date
        )

        # TeacherSchedule 업데이트
        if old_schedule
          old_schedule.update!(
            teacher: new_teacher,
            day: new_day,
            time_slot: new_time_slot,
            end_date: new_end_date
          )
        else
          # 기존 스케줄이 없으면 새로 생성
          TeacherSchedule.create!(
            user_id: enrollment.user_id,
            teacher: new_teacher,
            day: new_day,
            time_slot: new_time_slot,
            end_date: new_end_date
          )
        end

        Rails.logger.info "휴원 해제: #{enrollment.user.name} / #{new_teacher} / #{new_day} #{new_time_slot} / 첫수업=#{new_first_lesson_date} / 남은수업=#{weeks_remaining}회"
      else
        # 휴원 처리
        enrollment.update!(status: new_status)
      end
    end

    render json: { success: true }
  rescue ActiveRecord::RecordNotFound
    render json: { success: false, error: '수강 등록을 찾을 수 없습니다.' }, status: :not_found
  rescue => e
    render json: { success: false, error: e.message }, status: :unprocessable_entity
  end

  # 학생 스케줄 이동
  def move_student_schedule
    user_id = params[:user_id]
    from_teacher = params[:from_teacher]
    from_day = params[:from_day]
    from_time_slot = params[:from_time_slot]
    to_teacher = params[:to_teacher]
    to_day = params[:to_day]
    to_time_slot = params[:to_time_slot]

    ActiveRecord::Base.transaction do
      # UserEnrollment 찾기 (from_teacher로 찾기)
      enrollment = UserEnrollment.find_by(
        user_id: user_id,
        teacher: from_teacher,
        day: from_day,
        time_slot: from_time_slot,
        is_paid: true
      )

      unless enrollment
        render json: { success: false, error: '수강 정보를 찾을 수 없습니다.' }, status: :not_found
        return
      end

      # first_lesson_date는 유지, end_date만 재계산
      new_end_date = if enrollment.first_lesson_date.present? && enrollment.remaining_lessons > 0
        enrollment.first_lesson_date + ((enrollment.remaining_lessons - 1) * 7).days
      else
        enrollment.end_date
      end

      # 기존 TeacherSchedule 삭제
      old_schedule = TeacherSchedule.find_by(
        user_id: user_id,
        teacher: from_teacher,
        day: from_day,
        time_slot: from_time_slot
      )
      old_schedule&.destroy

      # UserEnrollment 업데이트 (선생님도 변경 가능)
      enrollment.update!(
        teacher: to_teacher,
        day: to_day,
        time_slot: to_time_slot,
        end_date: new_end_date
      )

      # 새로운 TeacherSchedule 생성
      TeacherSchedule.create!(
        user_id: user_id,
        teacher: to_teacher,
        day: to_day,
        time_slot: to_time_slot,
        end_date: new_end_date
      )

      Rails.logger.info "스케줄 이동: #{User.find(user_id).name} / #{from_teacher} #{from_day} #{from_time_slot} → #{to_teacher} #{to_day} #{to_time_slot}"
    end

    render json: { success: true }
  rescue => e
    Rails.logger.error "스케줄 이동 오류: #{e.message}"
    render json: { success: false, error: e.message }, status: :internal_server_error
  end

  # 미배치 학생 목록 조회 (모든 선생님 공통)
  def unscheduled_students
    # day와 time_slot이 null인 UserEnrollment 찾기 (모든 선생님)
    enrollments = UserEnrollment.where(
      day: nil,
      time_slot: nil,
      is_paid: true
    ).where('remaining_lessons > 0')

    # 유저별로 그룹핑하여 중복 제거, teacher 정보 포함
    students_hash = {}
    enrollments.each do |enrollment|
      user = enrollment.user
      if students_hash[user.id]
        # 이미 있으면 teacher 추가
        students_hash[user.id][:teachers] << enrollment.teacher unless students_hash[user.id][:teachers].include?(enrollment.teacher)
      else
        students_hash[user.id] = {
          id: user.id,
          username: user.username,
          name: user.name,
          teachers: [enrollment.teacher],
          remaining_lessons: enrollment.remaining_lessons
        }
      end
    end

    students = students_hash.values

    render json: { success: true, students: students }
  rescue => e
    Rails.logger.error "미배치 학생 조회 오류: #{e.message}"
    render json: { success: false, error: e.message }, status: :internal_server_error
  end

  # 미배치 학생을 스케줄에 배치
  def schedule_unscheduled_student
    user_id = params[:user_id]
    day = params[:day]
    time_slot = params[:time_slot]
    target_teacher = params[:teacher]

    ActiveRecord::Base.transaction do
      # UserEnrollment 찾기 (day, time_slot이 null인 것)
      # target_teacher의 수강 정보를 찾되, 없으면 다른 선생님의 미배치 수강 정보를 찾음
      enrollment = UserEnrollment.find_by(
        user_id: user_id,
        teacher: target_teacher,
        day: nil,
        time_slot: nil,
        is_paid: true
      )

      # target_teacher의 수강 정보가 없으면 다른 선생님의 미배치 수강 정보 찾기
      other_enrollment = nil
      unless enrollment
        other_enrollment = UserEnrollment.find_by(
          user_id: user_id,
          day: nil,
          time_slot: nil,
          is_paid: true
        )

        unless other_enrollment
          render json: { success: false, error: '수강 정보를 찾을 수 없습니다.' }, status: :not_found
          return
        end

        # 다른 선생님의 수강 정보를 target_teacher로 변경
        enrollment = other_enrollment
        enrollment.update!(teacher: target_teacher)
      end

      # end_date 재계산
      new_end_date = if enrollment.first_lesson_date.present? && enrollment.remaining_lessons > 0
        enrollment.first_lesson_date + ((enrollment.remaining_lessons - 1) * 7).days
      else
        Date.current + (enrollment.remaining_lessons * 7).days
      end

      # UserEnrollment 업데이트
      enrollment.update!(
        day: day,
        time_slot: time_slot,
        end_date: new_end_date
      )

      # TeacherSchedule 생성
      TeacherSchedule.create!(
        user_id: user_id,
        teacher: target_teacher,
        day: day,
        time_slot: time_slot,
        end_date: new_end_date
      )

      Rails.logger.info "미배치 학생 배치: #{User.find(user_id).name} / #{target_teacher} / #{day} #{time_slot}"
    end

    render json: { success: true }
  rescue => e
    Rails.logger.error "미배치 학생 배치 오류: #{e.message}"
    render json: { success: false, error: e.message }, status: :internal_server_error
  end

  # 학생 스케줄 해제
  def unschedule_student
    user_id = params[:user_id]
    day = params[:day]
    time_slot = params[:time_slot]
    teacher = params[:teacher]

    ActiveRecord::Base.transaction do
      # UserEnrollment 찾기
      enrollment = UserEnrollment.find_by(
        user_id: user_id,
        teacher: teacher,
        day: day,
        time_slot: time_slot,
        is_paid: true
      )

      unless enrollment
        render json: { success: false, error: '수강 정보를 찾을 수 없습니다.' }, status: :not_found
        return
      end

      # TeacherSchedule 삭제
      schedule = TeacherSchedule.find_by(
        user_id: user_id,
        teacher: teacher,
        day: day,
        time_slot: time_slot
      )
      schedule&.destroy

      # UserEnrollment는 유지하되 day, time_slot만 null로 (결제 정보 유지)
      enrollment.update!(
        day: nil,
        time_slot: nil
      )

      Rails.logger.info "스케줄 해제: #{User.find(user_id).name} / #{day} #{time_slot}"
    end

    render json: { success: true }
  rescue => e
    Rails.logger.error "스케줄 해제 오류: #{e.message}"
    render json: { success: false, error: e.message }, status: :internal_server_error
  end

  # 회원 상세 정보 조회 (시간표 관리용)
  def student_detail
    user = User.find(params[:id])

    # 보강/패스 신청 내역
    makeup_pass_requests = MakeupPassRequest.where(user_id: user.id)
                                            .order(created_at: :desc)
                                            .limit(10)
                                            .map do |req|
      {
        id: req.id,
        request_type: req.request_type,
        request_date: req.request_date,
        makeup_date: req.makeup_date,
        time_slot: req.time_slot,
        teacher: req.teacher,
        status: req.status,
        created_at: req.created_at.strftime('%Y-%m-%d %H:%M')
      }
    end

    # 결제 내역
    payments = Payment.where(user_id: user.id)
                      .order(payment_date: :desc)
                      .limit(10)
                      .map do |payment|
      {
        id: payment.id,
        teacher: payment.teacher,
        subject: payment.subject,
        lessons: payment.lessons,
        months: payment.months,
        payment_date: payment.payment_date.strftime('%Y-%m-%d'),
        first_lesson_date: payment.first_lesson_date&.strftime('%Y-%m-%d'),
        first_lesson_time: payment.first_lesson_time
      }
    end

    # 수강 등록 정보 (스케줄)
    enrollments = UserEnrollment.where(user_id: user.id, is_paid: true)
                                .order(created_at: :desc)
                                .map do |enrollment|
      {
        id: enrollment.id,
        teacher: enrollment.teacher,
        teacher_history: enrollment.teacher_history_display,
        subject: enrollment.subject,
        day: enrollment.day_korean,
        time_slot: enrollment.time_slot,
        remaining_lessons: enrollment.remaining_lessons,
        first_lesson_date: enrollment.first_lesson_date&.strftime('%Y-%m-%d'),
        end_date: enrollment.end_date&.strftime('%Y-%m-%d'),
        status: enrollment.status
      }
    end

    # 남은 수업/패스 횟수
    total_remaining_lessons = UserEnrollment.where(user_id: user.id, is_paid: true).sum(:remaining_lessons)
    remaining_passes = user.remaining_passes || 0

    render json: {
      success: true,
      user: {
        id: user.id,
        username: user.username,
        name: user.name,
        teacher: user.teacher
      },
      makeup_pass_requests: makeup_pass_requests,
      payments: payments,
      enrollments: enrollments,
      remaining_lessons: total_remaining_lessons,
      remaining_passes: remaining_passes
    }
  rescue ActiveRecord::RecordNotFound
    render json: { success: false, error: '회원을 찾을 수 없습니다.' }, status: :not_found
  rescue => e
    Rails.logger.error "회원 상세 정보 조회 오류: #{e.message}"
    render json: { success: false, error: e.message }, status: :internal_server_error
  end

  def toggle_absence
    Rails.logger.info "=== toggle_absence START ==="
    Rails.logger.info "params: #{params.inspect}"

    schedule = TeacherSchedule.find(params[:id])
    Rails.logger.info "schedule found: #{schedule.inspect}"

    # 현재 보고 있는 주차의 날짜 확인 (프론트엔드에서 전달)
    target_date = params[:target_date] ? Date.parse(params[:target_date]) : nil
    Rails.logger.info "target_date: #{target_date}"

    # 과거 수업일은 처리 불가 (target_date가 있는 경우에만 체크)
    if target_date && target_date < Date.current
      Rails.logger.info "REJECT: past date"
      render json: { success: false, message: '과거 수업은 결석 처리할 수 없습니다.' }, status: :unprocessable_entity
      return
    end

    # enrollment 찾기
    Rails.logger.info "Finding enrollment: user_id=#{schedule.user_id}, teacher=#{schedule.teacher}, day=#{schedule.day}, time_slot=#{schedule.time_slot}"
    enrollment = UserEnrollment.find_by(
      user_id: schedule.user_id,
      teacher: schedule.teacher,
      day: schedule.day,
      time_slot: schedule.time_slot,
      is_paid: true
    )
    Rails.logger.info "enrollment found: #{enrollment.inspect}"

    unless enrollment
      Rails.logger.error "REJECT: enrollment not found"
      render json: { success: false, message: '수강 정보를 찾을 수 없습니다.' }, status: :not_found
      return
    end

    if schedule.is_absent
      # 결석 취소: 수업 횟수 복구
      Rails.logger.info "Cancelling absence"
      schedule.update!(is_absent: false)
      enrollment.increment!(:remaining_lessons)
      message = '결석 처리가 취소되었습니다.'
    else
      # 결석 처리: 수업 횟수 차감
      Rails.logger.info "Marking absence"
      schedule.update!(is_absent: true)
      enrollment.decrement!(:remaining_lessons)
      message = '결석 처리되었습니다.'
    end

    Rails.logger.info "SUCCESS: #{message}"
    render json: {
      success: true,
      message: message,
      is_absent: schedule.is_absent,
      remaining_lessons: enrollment.remaining_lessons
    }
  rescue => e
    Rails.logger.error "Toggle absence error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    render json: { success: false, message: "오류가 발생했습니다: #{e.message}" }, status: :internal_server_error
  end

  # 결석 취소 + 보강 재신청
  def cancel_absence_and_reschedule
    user = User.find(params[:user_id])
    original_date = Date.parse(params[:original_date])
    cancelled_request_id = params[:cancelled_makeup_request_id]
    new_date = Date.parse(params[:new_date])
    new_time_slot = params[:new_time_slot]
    new_teacher = params[:new_teacher]

    ActiveRecord::Base.transaction do
      # 1. 취소된 보강 요청 찾기
      cancelled_request = MakeupPassRequest.find(cancelled_request_id)

      # 2. 원래 자리의 결석 처리 취소
      # original_date 날짜의 TeacherSchedule 찾기
      original_day = { 0 => 'sun', 1 => 'mon', 2 => 'tue', 3 => 'wed', 4 => 'thu', 5 => 'fri', 6 => 'sat' }[original_date.wday]
      original_enrollment = UserEnrollment.find_by(
        user_id: user.id,
        day: original_day,
        is_paid: true
      )

      if original_enrollment
        schedule = TeacherSchedule.find_by(
          user_id: user.id,
          teacher: original_enrollment.teacher,
          day: original_day,
          time_slot: original_enrollment.time_slot
        )

        if schedule
          schedule.update!(is_absent: false)
        end
      end

      # 3. 주차 계산 (new_date의 주차)
      week_number = ((new_date - new_date.beginning_of_month).to_i / 7) + 1

      # 4. 새로운 보강 신청 생성
      new_request = MakeupPassRequest.create!(
        user_id: user.id,
        request_type: 'makeup',
        request_date: original_date,  # 원래 수업일
        makeup_date: new_date,        # 선택한 보강 날짜
        time_slot: new_time_slot,
        teacher: new_teacher,
        week_number: week_number,
        content: "원래 자리가 꽉 차서 다른 시간으로 보강 재신청 (원래 수업일: #{original_date})",
        status: 'active'
      )

      # 5. 기존 취소된 요청 삭제
      cancelled_request.destroy

      # 6. 수업 횟수 복구 (보강 취소 시 차감되었던 것)
      enrollment = UserEnrollment.find_by(
        user_id: user.id,
        teacher: user.primary_teacher
      )
      if enrollment && enrollment.remaining_lessons >= 0
        enrollment.increment!(:remaining_lessons)
      end

      render json: {
        success: true,
        message: "#{user.name} 학생의 결석이 취소되고 #{new_date} #{new_time_slot.gsub('-', ':00-')}:00 #{new_teacher} 선생님으로 보강이 신청되었습니다."
      }
    end
  rescue => e
    Rails.logger.error "Error in cancel_absence_and_reschedule: #{e.message}"
    render json: { success: false, message: "처리 중 오류가 발생했습니다: #{e.message}" }, status: :unprocessable_entity
  end

  private

  def user_to_hash(user)
    total_remaining_lessons = user.user_enrollments.sum(:remaining_lessons)

    {
      'id' => user.id,
      'username' => user.username,
      'name' => user.name,
      'email' => user.email,
      'phone' => user.respond_to?(:phone) ? user.phone : nil,
      'teacher' => user.primary_teacher,
      'status' => user.status,
      'created_at' => user.created_at.to_s,
      'online_verification_image' => user.respond_to?(:online_verification_image) ? user.online_verification_image : nil,
      'no_show_count' => 0,
      'cancel_count' => 0,
      'is_blocked' => false,
      'remaining_passes' => user.respond_to?(:current_remaining_passes) ? user.current_remaining_passes : 0,
      'remaining_lessons' => total_remaining_lessons
    }
  end
end