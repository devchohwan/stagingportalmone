class LinkExistingPaymentsToEnrollments < ActiveRecord::Migration[8.0]
  def up
    # 기존 결제 데이터를 수강권과 연결
    Payment.where(enrollment_id: nil).find_each do |payment|
      enrollment = UserEnrollment.find_by(
        user_id: payment.user_id,
        subject: payment.subject,
        teacher: payment.teacher,
        is_paid: true
      )
      
      if enrollment
        payment.update_column(:enrollment_id, enrollment.id)
      end
    end
  end

  def down
    # Rollback 시에는 enrollment_id를 nil로 되돌림
    Payment.update_all(enrollment_id: nil)
  end
end
