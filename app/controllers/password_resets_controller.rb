class PasswordResetsController < ApplicationController
  def new
    @teachers = ['무성', '성균', '노네임', '로한', '범석', '두박', '오또', '지명', '도현']
  end

  def create
    # Call the monemusicpractice API to initiate password reset
    response = HTTParty.post(
      "http://localhost:3000/api/v1/auth/password_reset",
      body: {
        username: params[:username],
        name: params[:name],
        phone: params[:phone],
        teacher: params[:teacher]
      }.to_json,
      headers: { 'Content-Type' => 'application/json' }
    )

    if response.success?
      data = JSON.parse(response.body)
      redirect_to password_reset_edit_path(token: data['token'])
    else
      error_data = JSON.parse(response.body) rescue {}
      flash.now[:alert] = error_data['error'] || "정보가 일치하지 않습니다."
      @teachers = ['무성', '성균', '노네임', '로한', '범석', '두박', '오또', '지명', '도현']
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @token = params[:token]
    if @token.blank?
      flash[:alert] = '유효하지 않거나 만료된 요청입니다. 다시 시도해주세요.'
      redirect_to password_reset_path
    end
  end

  def update
    # Call the monemusicpractice API to update password
    response = HTTParty.patch(
      "http://localhost:3000/api/v1/auth/password_reset",
      body: {
        token: params[:token],
        password: params[:password],
        password_confirmation: params[:password_confirmation]
      }.to_json,
      headers: { 'Content-Type' => 'application/json' }
    )

    if response.success?
      flash[:alert_message] = '비밀번호가 변경되었습니다. 로그인 해주세요.'
      redirect_to login_path
    else
      error_data = JSON.parse(response.body) rescue {}
      flash[:alert] = error_data['error'] || "비밀번호 재설정에 실패했습니다."
      redirect_to password_reset_edit_path(token: params[:token])
    end
  end
end