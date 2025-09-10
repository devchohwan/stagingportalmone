class RegistrationsController < ApplicationController
  def new
    @teachers = ['무성', '성균', '노네임', '로한', '범석', '두박', '오또', '지명', '도현', '온라인']
  end

  def create
    # 비밀번호 확인 검증
    if params[:password] != params[:password_confirmation]
      flash.now[:alert] = "비밀번호와 비밀번호 확인이 일치하지 않습니다."
      @teachers = ['무성', '성균', '노네임', '로한', '범석', '두박', '오또', '지명', '도현', '온라인']
      render :new, status: :unprocessable_entity and return
    end
    
    # 전화번호 인증 확인
    unless session[:phone_verified] && session[:verified_phone] == params[:phone]
      flash.now[:alert] = "전화번호 인증을 완료해주세요."
      @teachers = ['무성', '성균', '노네임', '로한', '범석', '두박', '오또', '지명', '도현', '온라인']
      render :new, status: :unprocessable_entity and return
    end
    
    # 직접 데이터베이스에 사용자 생성
    user = User.new(
      username: params[:username],
      name: params[:name],
      phone: params[:phone],
      teacher: params[:teacher],
      status: 'pending',
      is_admin: false
    )
    
    # 온라인 수강생 인증 이미지 처리
    if params[:teacher] == '온라인' && params[:online_verification_image].present?
      uploaded_file = params[:online_verification_image]
      
      # 파일 저장 경로 설정
      filename = "#{SecureRandom.hex(8)}_#{uploaded_file.original_filename}"
      filepath = Rails.root.join('public', 'uploads', 'verifications', filename)
      
      # 디렉토리 생성
      FileUtils.mkdir_p(File.dirname(filepath))
      
      # 파일 저장
      File.open(filepath, 'wb') do |file|
        file.write(uploaded_file.read)
      end
      
      # DB에 파일 경로 저장
      user.online_verification_image = "/uploads/verifications/#{filename}"
    end
    
    # 비밀번호 설정
    user.password = params[:password]

    if user.save
      # 인증 세션 정리
      session[:phone_verified] = nil
      session[:verified_phone] = nil
      session[:phone_verification_id] = nil
      
      flash[:notice] = "signup_success"
      redirect_to login_path
    else
      flash.now[:alert] = user.errors.full_messages.join(", ")
      @teachers = ['무성', '성균', '노네임', '로한', '범석', '두박', '오또', '지명', '도현', '온라인']
      render :new, status: :unprocessable_entity
    end
  end
end