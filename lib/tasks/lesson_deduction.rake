namespace :lessons do
  desc "매시간 실행: 보강/패스 상태 업데이트 및 해당 시간 종료된 수업 자동 차감"
  task deduct_hourly: :environment do
    puts "=== 수업 차감 작업 시작 (#{Time.current}) ==="

    # 1. 보강/패스 상태 업데이트 (완료된 보강은 자동으로 차감됨)
    MakeupPassRequest.update_statuses
    puts "보강/패스 상태 업데이트 완료"

    # 2. 정규 수업 자동 차감 (현재 시각 기준)
    today = Date.current
    current_hour = Time.current.hour
    deducted_count = 0

    # UserEnrollment 기반으로 각 과목별 차감
    UserEnrollment.where(is_paid: true).where(status: 'active').find_each do |enrollment|
      user = enrollment.user

      # 남은 수업 없으면 건너뜀
      next if user.remaining_lessons.nil? || user.remaining_lessons <= 0

      # 첫 수업일 확인
      next unless enrollment.first_lesson_date.present?
      next if today < enrollment.first_lesson_date

      # 수업 시간대 파싱
      end_hour = enrollment.time_slot.split('-').last.to_i
      next unless current_hour == end_hour

      # 오늘이 수업 요일인지 확인
      lesson_wday = {
        'mon' => 1, 'tue' => 2, 'wed' => 3, 'thu' => 4,
        'fri' => 5, 'sat' => 6, 'sun' => 0
      }[enrollment.day]

      next unless today.wday == lesson_wday

      # 첫 수업일 이후 매주 같은 요일인지 확인
      weeks_passed = ((today - enrollment.first_lesson_date).to_i / 7).floor
      expected_lesson_date = enrollment.first_lesson_date + (weeks_passed * 7).days
      next unless today == expected_lesson_date

      # 패스/보강 확인
      has_pass_or_makeup = user.makeup_pass_requests
        .where(request_date: today)
        .where(status: ['active', 'completed'])
        .exists?

      if has_pass_or_makeup
        puts "#{user.name} (#{enrollment.subject}): 패스/보강으로 차감 건너뜀"
        next
      end

      # 수업 차감
      user.update!(remaining_lessons: user.remaining_lessons - 1)
      deducted_count += 1
      puts "#{user.name} (#{enrollment.subject}): #{current_hour}시 수업 종료 - 1회 차감 (남은: #{user.remaining_lessons})"
    end

    puts "=== 수업 차감 완료: 총 #{deducted_count}명 차감 ==="
  end
end
