namespace :enrollment_schedule_histories do
  desc "기존 수강권의 초기 스케줄 이력 생성"
  task seed_initial_data: :environment do
    puts "=== 기존 수강권의 초기 스케줄 이력 생성 시작 ==="

    # 이미 이력이 있는 수강권은 제외
    enrollments = UserEnrollment.where(
      "day IS NOT NULL AND time_slot IS NOT NULL AND first_lesson_date IS NOT NULL"
    ).where.not(
      id: EnrollmentScheduleHistory.select(:user_enrollment_id).distinct
    )

    created_count = 0

    enrollments.find_each do |enrollment|
      begin
        EnrollmentScheduleHistory.create!(
          user_enrollment_id: enrollment.id,
          day: enrollment.day,
          time_slot: enrollment.time_slot,
          changed_at: enrollment.created_at || Time.current,
          effective_from: enrollment.first_lesson_date
        )
        created_count += 1
        puts "#{enrollment.user.name} (#{enrollment.subject}): 초기 이력 생성 완료"
      rescue => e
        puts "#{enrollment.user.name} (#{enrollment.subject}): 실패 - #{e.message}"
      end
    end

    puts "=== 완료: 총 #{created_count}개의 초기 이력 생성 ==="
  end
end
