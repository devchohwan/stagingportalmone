class Teacher
  # 선생님 목록
  TEACHERS = ['무성', '범석', '두박', '도현', '로한', '지명', '성균', '오또', '노네임'].freeze
  SPECIAL_SUBJECT_TEACHERS = ['지명', '도현'].freeze

  # 각 선생님의 휴무일 정의 (요일 번호: 0=일, 1=월, 2=화, 3=수, 4=목, 5=금, 6=토)
  HOLIDAYS = {
    '무성' => [2, 3],           # 화, 수
    '범석' => [3, 4],           # 수, 목
    '두박' => [2, 3, 0],        # 화, 수, 일
    '도현' => [3, 4, 5, 0],     # 수, 목, 금, 일
    '로한' => [5, 6, 0],        # 금, 토, 일
    '지명' => [5, 6, 0],        # 금, 토, 일
    '성균' => [1, 6, 0],        # 월, 토, 일
    '오또' => [5],              # 금
    '노네임' => [2, 3]          # 화, 수
  }.freeze

  # 선생님이 특정 날짜에 휴무인지 확인
  def self.closed_on?(teacher_name, date)
    return false unless TEACHERS.include?(teacher_name)

    # 선생님 개별 휴무일 확인
    teacher_holidays = HOLIDAYS[teacher_name] || []
    teacher_holidays.include?(date.wday)
  end

  # 특수과목 선생님인지 확인
  def self.special_subject?(teacher_name)
    SPECIAL_SUBJECT_TEACHERS.include?(teacher_name)
  end

  # 학생이 선택 가능한 선생님 목록 (보강 신청 시)
  def self.available_for_student(student_teacher)
    if special_subject?(student_teacher)
      # 특수과목 학생은 자기 선생님만 선택 가능
      [student_teacher]
    else
      # 일반 학생은 온라인, 특수과목 선생님 제외
      TEACHERS - ['온라인'] - SPECIAL_SUBJECT_TEACHERS
    end
  end
end
