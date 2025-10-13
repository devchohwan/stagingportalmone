class Admin::ReservationsController < ApplicationController
  before_action :authenticate_admin!
  before_action :set_reservation, only: []
  skip_forgery_protection
  
  def index
    @service_type = params[:service] || 'practice'

    if @service_type == 'makeup'
      # 보충수업 시스템에서 데이터 가져오기
      fetch_makeup_reservations
    elsif @service_type == 'pitch'
      # 음정수업 시스템에서 데이터 가져오기
      fetch_pitch_reservations
    else
      # 예약 상태 자동 업데이트 (연습실 시스템)
      Reservation.where(status: ['active', 'in_use']).each(&:update_status_by_time!)
      
      # 연습실 시스템 (기존 로직)
      @reservations = Reservation.includes(:user, :room)
                                 .order(start_time: :desc)
      
      # 검색 기능 (이름/아이디)
      if params[:search].present?
        search_term = "%#{params[:search]}%"
        @reservations = @reservations.joins(:user)
                                    .where("users.name LIKE ? OR users.username LIKE ?", search_term, search_term)
      end
      
      # 필터링 옵션
      if params[:status].present?
        @reservations = @reservations.where(status: params[:status])
      end
      
      if params[:date].present?
        date = Date.parse(params[:date])
        @reservations = @reservations.where(start_time: date.beginning_of_day..date.end_of_day)
      end
    end
    
    @users = User.all
    
    # dashboard 폴더의 reservations.html.erb를 렌더링
    render 'admin/dashboard/reservations'
  end
  
  def content
    @service_type = params[:service] || 'practice'

    if @service_type == 'makeup'
      # 보충수업 시스템에서 데이터 가져오기
      fetch_makeup_reservations
    elsif @service_type == 'pitch'
      # 음정수업 시스템에서 데이터 가져오기
      fetch_pitch_reservations
    elsif @service_type == 'makeup_pass'
      # 보강/패스 시스템에서 데이터 가져오기
      fetch_makeup_pass_requests
    else
      # 연습실 시스템 (기존 로직)
      @reservations = Reservation.includes(:user, :room)
                                 .order(start_time: :desc)
      
      # 검색 기능 (이름/아이디)
      if params[:search].present?
        search_term = "%#{params[:search]}%"
        @reservations = @reservations.joins(:user)
                                    .where("users.name LIKE ? OR users.username LIKE ?", search_term, search_term)
      end
      
      # 필터링 옵션
      if params[:status].present?
        @reservations = @reservations.where(status: params[:status])
      end
      
      if params[:date].present?
        date = Date.parse(params[:date])
        @reservations = @reservations.where(start_time: date.beginning_of_day..date.end_of_day)
      end
    end
    
    @users = User.all
    
    # 부분 렌더링으로 콘텐츠만 반환
    render partial: 'admin/dashboard/reservations_content', locals: { 
      reservations: @reservations, 
      service_type: @service_type 
    }
  end
  
  def approve_reservation
    @service_type = params[:service] || 'practice'

    if @service_type == 'pitch'
      # 음정수업 시스템 DB 직접 업데이트 - PitchReservation 모델 사용
      reservation = PitchReservation.find(params[:id])
      # validation 없이 직접 업데이트 (관리자 권한)
      if reservation.update_attribute(:status, 'approved')
        reservation.update_columns(approved_at: Time.current, approved_by: 'admin')
        # 승인 시 SMS 발송
        if reservation.user && reservation.user.phone.present?
          sms_service = SmsService.new
          result = sms_service.send_pitch_approval_notification(reservation.user.phone, reservation.user.name, reservation)

          if result[:success]
            Rails.logger.info "음정수업 승인 알림 SMS 전송 성공: #{reservation.user.phone}"
          else
            Rails.logger.error "음정수업 승인 알림 SMS 전송 실패: #{reservation.user.phone}"
          end
        end
        redirect_back(fallback_location: admin_reservations_path(service: 'pitch'), notice: '예약이 승인되었습니다.')
      else
        redirect_back(fallback_location: admin_reservations_path(service: 'pitch'), alert: '예약 승인에 실패했습니다.')
      end
    elsif @service_type == 'makeup'
      # 보충수업 시스템 DB 직접 업데이트 - MakeupReservation 모델 사용
      reservation = MakeupReservation.find(params[:id])
      # validation 없이 직접 업데이트 (관리자 권한)
      if reservation.update_attribute(:status, 'active')
        # 승인 시 SMS 발송
        if reservation.user && reservation.user.phone.present?
          sms_service = SmsService.new
          result = sms_service.send_makeup_approval_notification(reservation.user.phone, reservation.user.name, reservation)
          
          if result[:success]
            Rails.logger.info "보충수업 승인 알림 SMS 전송 성공: #{reservation.user.phone}"
          else
            Rails.logger.error "보충수업 승인 알림 SMS 전송 실패: #{reservation.user.phone}"
          end
        end
        redirect_back(fallback_location: admin_reservations_path(service: 'makeup'), notice: '예약이 승인되었습니다.')
      else
        redirect_back(fallback_location: admin_reservations_path(service: 'makeup'), alert: '예약 승인에 실패했습니다.')
      end
    else
      # 연습실 시스템 예약은 자동 승인
      redirect_back(fallback_location: admin_reservations_path, alert: '연습실 예약은 자동 승인됩니다.')
    end
  end
  
  def destroy
    # JSON body에서 service 파라미터 읽기
    service = params[:service] || JSON.parse(request.body.read)['service'] rescue nil

    if service == 'pitch'
      # 음정수업 예약 삭제
      reservation = PitchReservation.find(params[:id])
      reservation.destroy
    elsif service == 'makeup'
      # 보충수업 예약 삭제
      reservation = MakeupReservation.find(params[:id])
      reservation.destroy
    elsif service == 'makeup_pass'
      # 보강/패스 예약 삭제
      reservation = MakeupPassRequest.find(params[:id])
      reservation.destroy
    else
      # 연습실 예약 삭제
      reservation = Reservation.find(params[:id])
      reservation.destroy
    end
    
    respond_to do |format|
      format.html {
        redirect_params = {}
        redirect_params[:search] = params[:search] if params[:search].present?
        redirect_params[:status] = params[:status] if params[:status].present?
        redirect_params[:date] = params[:date] if params[:date].present?
        redirect_params[:service] = service if service.present?
        redirect_to admin_reservations_path(redirect_params), notice: '예약이 삭제되었습니다.'
      }
      format.json { render json: { success: true, message: '예약이 삭제되었습니다.' } }
    end
  end
  
  def lesson_content
    if params[:service] == 'pitch'
      reservation = PitchReservation.find(params[:id])

      render json: {
        success: true,
        user_name: reservation.user.name,
        date: reservation.start_time.strftime('%Y년 %m월 %d일'),
        time: "#{reservation.start_time.strftime('%H:%M')} - #{reservation.end_time.strftime('%H:%M')}",
        week_number: reservation.week_number,
        notes: reservation.notes || '메모 없음'
      }
    else
      reservation = MakeupReservation.find(params[:id])

      Rails.logger.info "=== Lesson Content Debug ==="
      Rails.logger.info "Reservation ID: #{reservation.id}"
      Rails.logger.info "Week Number: #{reservation.week_number.inspect}"
      Rails.logger.info "Lesson Content: #{reservation.lesson_content.inspect}"

      render json: {
        success: true,
        user_name: reservation.user.name,
        date: reservation.start_time.strftime('%Y년 %m월 %d일'),
        time: "#{reservation.start_time.strftime('%H:%M')} - #{reservation.end_time.strftime('%H:%M')}",
        week_number: reservation.week_number,
        lesson_content: reservation.lesson_content
      }
    end
  rescue ActiveRecord::RecordNotFound
    render json: { success: false, error: '예약을 찾을 수 없습니다.' }, status: :not_found
  end
  
  def makeup_cancellation_reason
    reservation = MakeupReservation.find(params[:id])
    
    render json: {
      success: true,
      user_name: reservation.user.name,
      date: reservation.start_time.strftime('%Y년 %m월 %d일'),
      time: "#{reservation.start_time.strftime('%H:%M')} - #{reservation.end_time.strftime('%H:%M')}",
      room: "#{reservation.makeup_room.number}석",
      cancellation_reason: reservation.cancellation_reason
    }
  rescue ActiveRecord::RecordNotFound
    render json: { success: false, error: '예약을 찾을 수 없습니다.' }, status: :not_found
  end
  
  def bulk_delete
    reservation_ids = params[:reservation_ids]
    service = params[:service]

    Rails.logger.info "=== BULK DELETE ==="
    Rails.logger.info "IDs: #{reservation_ids.inspect}"
    Rails.logger.info "Service: #{service}"

    if reservation_ids.blank?
      render json: { success: false, error: '삭제할 예약을 선택해주세요.' }
      return
    end

    begin
      deleted_count = 0

      if service == 'pitch'
        # 음정수업 예약 삭제
        reservations = PitchReservation.where(id: reservation_ids)
        deleted_count = reservations.count
        reservations.destroy_all
      elsif service == 'makeup'
        # 보충수업 예약 삭제
        reservations = MakeupReservation.where(id: reservation_ids)
        deleted_count = reservations.count
        reservations.destroy_all
      else
        # 연습실 예약 삭제
        reservations = Reservation.where(id: reservation_ids)
        deleted_count = reservations.count
        reservations.destroy_all
      end
      
      Rails.logger.info "Deleted #{deleted_count} reservations"
      
      render json: { 
        success: true, 
        deleted_count: deleted_count,
        message: "#{deleted_count}개의 예약이 삭제되었습니다."
      }
    rescue => e
      Rails.logger.error "Bulk delete error: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      
      render json: { 
        success: false, 
        error: "삭제 중 오류가 발생했습니다: #{e.message}"
      }
    end
  end
  
  def update_status
    Rails.logger.info "=== update_status called ==="
    Rails.logger.info "Params: #{params.inspect}"

    redirect_params = {}
    redirect_params[:search] = params[:search] if params[:search].present?
    redirect_params[:status] = params[:filter_status] if params[:filter_status].present?
    redirect_params[:date] = params[:date] if params[:date].present?
    redirect_params[:service] = params[:service] if params[:service].present?

    # service 파라미터로 음정수업/보충수업/연습실/보강패스 구분
    if params[:service] == 'makeup_pass'
      # 보강/패스 시스템 예약 상태 변경 - MakeupPassRequest 모델 사용
      Rails.logger.info "Updating makeup_pass request #{params[:id]} to status #{params[:status]}"
      request_record = MakeupPassRequest.find(params[:id])

      # validation 없이 직접 업데이트 (관리자 권한)
      if request_record.update_columns(status: params[:status])
        respond_to do |format|
          format.html { redirect_to admin_reservations_path(redirect_params), notice: '상태가 변경되었습니다.' }
          format.json { render json: { success: true, message: '상태가 변경되었습니다.' } }
        end
      else
        Rails.logger.error "Update failed"
        respond_to do |format|
          format.html { redirect_to admin_reservations_path(redirect_params), alert: "상태 변경 실패" }
          format.json { render json: { success: false, error: '상태 변경 실패' }, status: :unprocessable_entity }
        end
      end
    elsif params[:service] == 'pitch'
      # 음정수업 시스템 예약 상태 변경 - PitchReservation 모델 사용
      Rails.logger.info "Updating pitch reservation #{params[:id]} to status #{params[:status]}"
      reservation = PitchReservation.find(params[:id])
      # validation 없이 직접 업데이트 (관리자 권한)
      # cancelled 상태로 변경 시 cancelled_by를 'admin'으로 설정
      update_attrs = { status: params[:status] }
      update_attrs[:cancelled_by] = 'admin' if params[:status] == 'cancelled'
      update_attrs[:cancelled_at] = Time.current if params[:status] == 'cancelled'

      # 관리자는 validation 무시하고 강제 업데이트
      # no_show나 cancelled 상태로 변경할 때는 콜백을 실행해야 페널티가 적용됨
      if params[:status] == 'no_show' || (params[:status] == 'cancelled' && reservation.status == 'approved')
        # save(validate: false)를 사용하여 validation은 무시하되 콜백은 실행
        reservation.assign_attributes(update_attrs)
        success = reservation.save(validate: false)
      else
        # 다른 상태 변경은 콜백 없이 직접 업데이트
        success = reservation.update_columns(update_attrs)
      end

      if success
        # 승인 시 SMS 발송
        if params[:status] == 'approved' && reservation.user && reservation.user.phone.present?
          reservation.update_columns(approved_at: Time.current, approved_by: 'admin')
          sms_service = SmsService.new
          result = sms_service.send_pitch_approval_notification(reservation.user.phone, reservation.user.name, reservation)

          if result[:success]
            Rails.logger.info "음정수업 승인 알림 SMS 전송 성공: #{reservation.user.phone}"
          else
            Rails.logger.error "음정수업 승인 알림 SMS 전송 실패: #{reservation.user.phone}"
          end
        end

        respond_to do |format|
          format.html { redirect_to admin_reservations_path(redirect_params), notice: '예약 상태가 변경되었습니다.' }
          format.json { render json: { success: true, message: '예약 상태가 변경되었습니다.' } }
          format.turbo_stream {
            render turbo_stream: turbo_stream.replace(
              "reservation_status_#{reservation.id}",
              partial: "admin/dashboard/reservation_status_form",
              locals: { reservation: reservation, service_type: params[:service] }
            )
          }
        end
      else
        Rails.logger.error "Update failed: #{reservation.errors.full_messages.join(', ')}"
        respond_to do |format|
          format.html { redirect_to admin_reservations_path(redirect_params), alert: "상태 변경 실패: #{reservation.errors.full_messages.join(', ')}" }
          format.json { render json: { success: false, error: reservation.errors.full_messages.join(', ') }, status: :unprocessable_entity }
        end
      end
    elsif params[:service] == 'makeup'
      # 보충수업 시스템 예약 상태 변경 - MakeupReservation 모델 사용
      Rails.logger.info "Updating makeup reservation #{params[:id]} to status #{params[:status]}"
      reservation = MakeupReservation.find(params[:id])
      # validation 없이 직접 업데이트 (관리자 권한)
      # cancelled 상태로 변경 시 cancelled_by를 'admin'으로 설정
      update_attrs = { status: params[:status] }
      update_attrs[:cancelled_by] = 'admin' if params[:status] == 'cancelled'
      # rejected 상태는 거절로 처리 (페널티 없음, cancelled_by 설정하지 않음)
      
      # 관리자는 validation 무시하고 강제 업데이트
      # no_show나 cancelled 상태로 변경할 때는 콜백을 실행해야 페널티가 적용됨
      if params[:status] == 'no_show' || (params[:status] == 'cancelled' && reservation.cancelled_by != 'admin')
        # save(validate: false)를 사용하여 validation은 무시하되 콜백은 실행
        reservation.assign_attributes(update_attrs)
        success = reservation.save(validate: false)
      else
        # 다른 상태 변경은 콜백 없이 직접 업데이트
        success = reservation.update_columns(update_attrs)
      end
      
      if success
        # 승인 시 SMS 발송
        if params[:status] == 'active' && reservation.user && reservation.user.phone.present?
          sms_service = SmsService.new
          result = sms_service.send_makeup_approval_notification(reservation.user.phone, reservation.user.name, reservation)
          
          if result[:success]
            Rails.logger.info "보충수업 승인 알림 SMS 전송 성공: #{reservation.user.phone}"
          else
            Rails.logger.error "보충수업 승인 알림 SMS 전송 실패: #{reservation.user.phone}"
          end
        end
        
        # 거절 시 SMS 발송
        if params[:status] == 'rejected' && reservation.user && reservation.user.phone.present?
          sms_service = SmsService.new
          result = sms_service.send_rejection_notification(reservation.user.phone, reservation.user.name, reservation)
          
          if result[:success]
            Rails.logger.info "거절 알림 SMS 전송 성공: #{reservation.user.phone}"
          else
            Rails.logger.error "거절 알림 SMS 전송 실패: #{reservation.user.phone}"
          end
        end
        respond_to do |format|
          format.html { redirect_to admin_reservations_path(redirect_params), notice: '예약 상태가 변경되었습니다.' }
          format.json { render json: { success: true, message: '예약 상태가 변경되었습니다.' } }
          format.turbo_stream {
            render turbo_stream: turbo_stream.replace(
              "reservation_status_#{reservation.id}",
              partial: "admin/dashboard/reservation_status_form",
              locals: { reservation: reservation, service_type: params[:service] }
            )
          }
        end
      else
        Rails.logger.error "Update failed: #{reservation.errors.full_messages.join(', ')}"
        respond_to do |format|
          format.html { redirect_to admin_reservations_path(redirect_params), alert: "상태 변경 실패: #{reservation.errors.full_messages.join(', ')}" }
          format.json { render json: { success: false, error: reservation.errors.full_messages.join(', ') }, status: :unprocessable_entity }
        end
      end
    else
      # 연습실 시스템 예약 상태 변경
      reservation = Reservation.find(params[:id])
      # cancelled 상태로 변경 시 cancelled_by를 'admin'으로 설정
      update_attrs = { status: params[:status] }
      update_attrs[:cancelled_by] = 'admin' if params[:status] == 'cancelled'
      # rejected 상태는 거절로 처리 (페널티 없음)
      
      # 관리자는 validation 무시하고 강제 업데이트
      # no_show나 cancelled 상태로 변경할 때는 콜백을 실행해야 페널티가 적용됨
      if params[:status] == 'no_show' || (params[:status] == 'cancelled' && reservation.cancelled_by != 'admin')
        # save(validate: false)를 사용하여 validation은 무시하되 콜백은 실행
        reservation.assign_attributes(update_attrs)
        success = reservation.save(validate: false)
      else
        # 다른 상태 변경은 콜백 없이 직접 업데이트
        success = reservation.update_columns(update_attrs)
      end
      
      if success
        # 거절 시 SMS 발송
        if params[:status] == 'rejected' && reservation.user && reservation.user.phone.present?
          sms_service = SmsService.new
          result = sms_service.send_rejection_notification(reservation.user.phone, reservation.user.name, reservation)
          
          if result[:success]
            Rails.logger.info "거절 알림 SMS 전송 성공: #{reservation.user.phone}"
          else
            Rails.logger.error "거절 알림 SMS 전송 실패: #{reservation.user.phone}"
          end
        end
        
        respond_to do |format|
          format.html { redirect_to admin_reservations_path(redirect_params), notice: '예약 상태가 변경되었습니다.' }
          format.json { render json: { success: true, message: '예약 상태가 변경되었습니다.' } }
          format.turbo_stream {
            render turbo_stream: turbo_stream.replace(
              "reservation_status_#{reservation.id}",
              partial: "admin/dashboard/reservation_status_form",
              locals: { reservation: reservation, service_type: params[:service] }
            )
          }
        end
      else
        Rails.logger.error "Update failed: #{reservation.errors.full_messages.join(', ')}"
        respond_to do |format|
          format.html { redirect_to admin_reservations_path(redirect_params), alert: "상태 변경 실패: #{reservation.errors.full_messages.join(', ')}" }
          format.json { render json: { success: false, error: reservation.errors.full_messages.join(', ') }, status: :unprocessable_entity }
        end
      end
    end
  rescue => e
    Rails.logger.error "Error in update_status: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    respond_to do |format|
      format.html { redirect_to admin_reservations_path(redirect_params), alert: "오류 발생: #{e.message}" }
      format.json { render json: { error: e.message }, status: :internal_server_error }
    end
  end
  
  private
  
  def set_reservation
    @reservation = Reservation.find(params[:id])
  end
  
  # ApplicationController의 authenticate_admin! 사용하도록 제거
  
  def fetch_makeup_reservations
    # 시간이 지난 보충수업 상태를 자동으로 업데이트
    MakeupReservation.update_status_by_time!

    # 보충수업은 makeup_reservations 테이블에서 조회
    @reservations = MakeupReservation.includes(:user, :makeup_room)
                                     .order(start_time: :desc)

    Rails.logger.info "Makeup reservations found: #{@reservations.count}"

    # 검색 기능 (이름/아이디)
    if params[:search].present?
      search_term = "%#{params[:search]}%"
      @reservations = @reservations.joins(:user)
                                   .where("users.name LIKE ? OR users.username LIKE ?", search_term, search_term)
    end

    # 필터링 옵션
    if params[:status].present?
      @reservations = @reservations.where(status: params[:status])
    end

    if params[:date].present?
      date = Date.parse(params[:date])
      @reservations = @reservations.where(start_time: date.beginning_of_day..date.end_of_day)
    end

    Rails.logger.info "After filters - Makeup reservations: #{@reservations.count}"

  rescue => e
    @reservations = []
    Rails.logger.error "Error fetching makeup reservations: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
  end

  def fetch_pitch_reservations
    # 시간이 지난 음정수업 상태를 자동으로 업데이트
    PitchReservation.update_status_by_time!

    # 음정수업은 pitch_reservations 테이블에서 조회
    @reservations = PitchReservation.includes(:user, :pitch_room)
                                    .order(start_time: :desc)

    Rails.logger.info "Pitch reservations found: #{@reservations.count}"

    # 검색 기능 (이름/아이디)
    if params[:search].present?
      search_term = "%#{params[:search]}%"
      @reservations = @reservations.joins(:user)
                                   .where("users.name LIKE ? OR users.username LIKE ?", search_term, search_term)
    end

    # 필터링 옵션
    if params[:status].present?
      @reservations = @reservations.where(status: params[:status])
    end

    if params[:date].present?
      date = Date.parse(params[:date])
      @reservations = @reservations.where(start_time: date.beginning_of_day..date.end_of_day)
    end

    Rails.logger.info "After filters - Pitch reservations: #{@reservations.count}"

  rescue => e
    @reservations = []
    Rails.logger.error "Error fetching pitch reservations: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
  end

  def fetch_makeup_pass_requests
    # 시간이 지난 보강/패스 상태를 자동으로 업데이트
    MakeupPassRequest.update_statuses

    # 보강/패스는 makeup_pass_requests 테이블에서 조회
    @reservations = MakeupPassRequest.includes(:user)
                                     .order(created_at: :desc)

    Rails.logger.info "Makeup/Pass requests found: #{@reservations.count}"

    # 검색 기능 (이름/아이디)
    if params[:search].present?
      search_term = "%#{params[:search]}%"
      @reservations = @reservations.joins(:user)
                                   .where("users.name LIKE ? OR users.username LIKE ?", search_term, search_term)
    end

    # 필터링 옵션
    if params[:status].present?
      @reservations = @reservations.where(status: params[:status])
    end

    if params[:date].present?
      date = Date.parse(params[:date])
      # 보강인 경우 makeup_date, 패스인 경우 request_date 기준으로 필터
      @reservations = @reservations.where(
        "(request_type = 'makeup' AND DATE(makeup_date) = ?) OR (request_type = 'pass' AND DATE(request_date) = ?)",
        date, date
      )
    end

    Rails.logger.info "After filters - Makeup/Pass requests: #{@reservations.count}"

  rescue => e
    @reservations = []
    Rails.logger.error "Error fetching makeup/pass requests: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
  end
end