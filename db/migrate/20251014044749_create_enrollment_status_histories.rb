class CreateEnrollmentStatusHistories < ActiveRecord::Migration[8.0]
  def change
    create_table :enrollment_status_histories do |t|
      t.references :user_enrollment, null: false, foreign_key: true
      t.string :status, null: false  # 'active' 또는 'on_leave'
      t.datetime :changed_at, null: false  # 상태 변경 시각
      t.text :notes  # 메모 (예: 휴원 사유, 복귀 시간대 등)

      t.timestamps
    end

    add_index :enrollment_status_histories, [:user_enrollment_id, :changed_at]
  end
end
