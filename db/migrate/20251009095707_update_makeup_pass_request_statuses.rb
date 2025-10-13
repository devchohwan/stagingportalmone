class UpdateMakeupPassRequestStatuses < ActiveRecord::Migration[8.0]
  def up
    # cancelled_at 컬럼 추가
    add_column :makeup_pass_requests, :cancelled_at, :datetime

    # 기존 데이터 상태 변경: pending/approved -> active
    execute <<-SQL
      UPDATE makeup_pass_requests
      SET status = 'active'
      WHERE status IN ('pending', 'approved')
    SQL
  end

  def down
    remove_column :makeup_pass_requests, :cancelled_at

    # 롤백 시 active -> approved로 변경
    execute <<-SQL
      UPDATE makeup_pass_requests
      SET status = 'approved'
      WHERE status = 'active'
    SQL
  end
end
