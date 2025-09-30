class Admin::Pitch::PenaltiesController < ApplicationController
  before_action :authenticate_admin!

  def index
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
  end

  def reset
    @penalty = PitchPenalty.find(params[:id])
    @penalty.update!(
      no_show_count: 0,
      cancel_count: 0,
      is_blocked: false
    )
    redirect_to admin_pitch_penalties_path, notice: "#{@penalty.user.name}님의 패널티가 초기화되었습니다."
  end
end