class UserEnrollment < ApplicationRecord
  belongs_to :user

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
end
