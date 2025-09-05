class RegistrationsController < ApplicationController
  def new
    @teachers = ['무성', '성균', '노네임', '로한', '범석', '두박', '오또', '지명', '도현']
  end

  def create
    # 직접 데이터베이스에 사용자 생성
    user = User.new(
      username: params[:username],
      password: params[:password],
      password_confirmation: params[:password_confirmation],
      name: params[:name],
      phone: params[:phone],
      teacher: params[:teacher],
      status: 'pending',
      is_admin: false
    )

    if user.save
      flash[:notice] = "signup_success"
      redirect_to login_path
    else
      flash.now[:alert] = user.errors.full_messages.join(", ")
      @teachers = ['무성', '성균', '노네임', '로한', '범석', '두박', '오또', '지명', '도현']
      render :new, status: :unprocessable_entity
    end
  end
end