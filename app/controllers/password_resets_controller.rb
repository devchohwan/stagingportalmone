class PasswordResetsController < ApplicationController
  def new
    @teachers = ['무성', '성균', '노네임', '로한', '범석', '두박', '오또', '지명', '도현', '리아', '성환']
  end

  def create
    # 사용자 정보 확인
    user = User.find_by(
      username: params[:username],
      name: params[:name],
      phone: params[:phone].gsub(/[^0-9]/, ''),
      teacher: params[:teacher]
    )

    if user.nil?
      flash.now[:alert] = "입력하신 정보와 일치하는 계정을 찾을 수 없습니다."
      @teachers = ['무성', '성균', '노네임', '로한', '범석', '두박', '오또', '지명', '도현', '리아', '성환']
      render :new, status: :unprocessable_entity
      return
    end

    # 세션에 사용자 ID 저장
    session[:reset_user_id] = user.id
    session[:reset_phone] = user.phone
    
    # 비밀번호 재설정 단계로 이동
    redirect_to password_reset_edit_path
  end

  def edit
    # 세션에서 사용자 정보 확인
    if session[:reset_user_id].blank?
      flash[:alert] = '유효하지 않거나 만료된 요청입니다. 다시 시도해주세요.'
      redirect_to password_reset_path
      return
    end
    
    @user = User.find_by(id: session[:reset_user_id])
    if @user.nil?
      flash[:alert] = '유효하지 않거나 만료된 요청입니다. 다시 시도해주세요.'
      redirect_to password_reset_path
    end
  end

  def update
    # 세션에서 사용자 정보 확인
    if session[:reset_user_id].blank?
      flash[:alert] = '유효하지 않거나 만료된 요청입니다.'
      redirect_to password_reset_path
      return
    end
    
    user = User.find_by(id: session[:reset_user_id])
    if user.nil?
      flash[:alert] = '유효하지 않거나 만료된 요청입니다.'
      redirect_to password_reset_path
      return
    end
    
    # SMS 인증 확인
    unless session[:phone_verified] == true && session[:verified_phone] == user.phone
      flash[:alert] = '전화번호 인증을 완료해주세요.'
      redirect_to password_reset_edit_path
      return
    end

    # 비밀번호 확인
    if params[:password] != params[:password_confirmation]
      flash[:alert] = '새 비밀번호와 비밀번호 확인이 일치하지 않습니다.'
      redirect_to password_reset_edit_path
      return
    end
    
    if params[:password].to_s.length < 6
      flash[:alert] = '새 비밀번호는 최소 6자 이상이어야 합니다.'
      redirect_to password_reset_edit_path
      return
    end

    # 비밀번호 업데이트
    if user.update(password: params[:password])
      # 세션 정리
      session.delete(:reset_user_id)
      session.delete(:reset_phone)
      session.delete(:phone_verified)
      session.delete(:verified_phone)
      session.delete(:phone_verification_id)
      
      flash[:alert_message] = '비밀번호가 변경되었습니다. 로그인 해주세요.'
      redirect_to login_path
    else
      flash[:alert] = '비밀번호 재설정에 실패했습니다.'
      redirect_to password_reset_edit_path
    end
  end
end