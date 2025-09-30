class Admin::PenaltiesController < ApplicationController
  before_action :authenticate_admin!

  def index
    # 연습실 페널티
    practice_penalties = Penalty.includes(:user)
                                .where(month: Date.current.month, year: Date.current.year)

    # 음정수업 페널티
    pitch_penalties = PitchPenalty.includes(:user)
                                  .where(month: Date.current.month, year: Date.current.year)

    Rails.logger.info "========== PENALTY DEBUG =========="
    Rails.logger.info "Practice penalties count: #{practice_penalties.count}"
    Rails.logger.info "Pitch penalties count: #{pitch_penalties.count}"

    # 검색 기능 (이름/아이디)
    if params[:search].present?
      search_term = "%#{params[:search]}%"
      practice_penalties = practice_penalties.joins(:user)
                                             .where("users.name LIKE ? OR users.username LIKE ?", search_term, search_term)
      pitch_penalties = pitch_penalties.joins(:user)
                                       .where("users.name LIKE ? OR users.username LIKE ?", search_term, search_term)
    end

    # 차단된 회원만 보기
    if params[:blocked] == 'true'
      practice_penalties = practice_penalties.where(is_blocked: true)
      pitch_penalties = pitch_penalties.where(is_blocked: true)
    end

    # 서비스 필터
    if params[:service] == 'practice'
      @penalties = practice_penalties.order(created_at: :desc)
    elsif params[:service] == 'pitch'
      @penalties = pitch_penalties.order(created_at: :desc)
      Rails.logger.info "Pitch filter - penalties count: #{@penalties.count}"
      @penalties.each do |p|
        Rails.logger.info "- User: #{p.user.username}, Cancel: #{p.cancel_count}, Blocked: #{p.is_blocked}"
      end
    else
      # 모든 페널티 합치기
      @penalties = (practice_penalties.to_a + pitch_penalties.to_a).sort_by(&:created_at).reverse
      Rails.logger.info "All services - total penalties: #{@penalties.count}"

      # admin 페널티 확인
      admin_penalties = @penalties.select { |p| p.user.username == 'admin' }
      Rails.logger.info "Admin penalties found: #{admin_penalties.count}"
      admin_penalties.each do |p|
        Rails.logger.info "- #{p.class.name}: Cancel=#{p.cancel_count}, NoShow=#{p.no_show_count}, Blocked=#{p.is_blocked}"
      end
    end

    Rails.logger.info "@penalties final count: #{@penalties.count}"
    Rails.logger.info "=================================="
  end

  def reset
    if params[:type] == 'pitch'
      @penalty = PitchPenalty.find(params[:id])
    else
      @penalty = Penalty.find(params[:id])
    end

    @penalty.update!(
      no_show_count: 0,
      cancel_count: 0,
      is_blocked: false
    )
    redirect_to admin_penalties_path, notice: "#{@penalty.user.name}님의 패널티가 초기화되었습니다."
  end
end