class UserEnrollment < ApplicationRecord
  belongs_to :user

  # 선생님 변경 전 콜백
  before_update :track_teacher_change

  # 요일 한글 변환
  def day_korean
    day_map = {
      'mon' => '월요일',
      'tue' => '화요일',
      'wed' => '수요일',
      'thu' => '목요일',
      'fri' => '금요일',
      'sat' => '토요일',
      'sun' => '일요일'
    }
    day_map[day] || day
  end

  # 시간 표시
  def time_display
    time_slot || ''
  end

  # 선생님 변경 이력 배열로 반환
  def teacher_history_array
    return [] if teacher_history.blank?
    teacher_history.split(' -> ')
  end

  # 선생님 변경 이력 문자열로 반환
  def teacher_history_display
    return teacher if teacher_history.blank?
    "#{teacher_history} -> #{teacher}"
  end

  private

  # 선생님 변경 추적
  def track_teacher_change
    if teacher_changed? && teacher_was.present?
      if teacher_history.blank?
        self.teacher_history = teacher_was
      else
        self.teacher_history = "#{teacher_history} -> #{teacher_was}"
      end
    end
  end
end
