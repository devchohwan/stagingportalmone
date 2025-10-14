class BackfillEnrollmentStatusHistories < ActiveRecord::Migration[8.0]
  def up
    # 모든 활성/휴원 상태의 수강권에 대해 초기 히스토리 생성
    UserEnrollment.find_each do |enrollment|
      # 첫수업일이 있고, 이미 히스토리가 없는 경우만 생성
      if enrollment.first_lesson_date.present? && enrollment.enrollment_status_histories.empty?
        EnrollmentStatusHistory.create!(
          user_enrollment_id: enrollment.id,
          status: enrollment.status,
          changed_at: enrollment.first_lesson_date.to_time.in_time_zone,
          notes: "Initial status from migration"
        )
      end
    end
  end

  def down
    # Rollback 시 마이그레이션으로 생성된 히스토리 삭제
    EnrollmentStatusHistory.where(notes: "Initial status from migration").destroy_all
  end
end
