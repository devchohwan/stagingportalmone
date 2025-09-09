class CreateMakeupLessons < ActiveRecord::Migration[8.0]
  def change
    create_table :makeup_lessons do |t|
      t.references :user, null: false, foreign_key: true
      t.string :teacher_name, null: false
      t.string :subject, null: false # 보컬, 기타, 믹스, 작곡 등
      t.date :missed_date # 결석한 수업 날짜
      t.text :reason # 보충 사유
      t.datetime :requested_datetime # 희망 보충 일시
      t.datetime :confirmed_datetime # 확정된 보충 일시
      t.string :status, default: 'pending' # pending, approved, rejected, completed, cancelled
      t.text :admin_note # 관리자 메모
      t.string :location # 수업 장소
      t.integer :duration_minutes, default: 60 # 수업 시간(분)
      
      t.timestamps
    end
    
    add_index :makeup_lessons, :status
    add_index :makeup_lessons, :teacher_name
    add_index :makeup_lessons, [:user_id, :status]
    
    # 보충수업 가능 시간대 테이블
    create_table :makeup_availabilities do |t|
      t.string :teacher_name, null: false
      t.integer :day_of_week # 0=일요일, 6=토요일
      t.time :start_time
      t.time :end_time
      t.boolean :is_active, default: true
      
      t.timestamps
    end
    
    add_index :makeup_availabilities, :teacher_name
    add_index :makeup_availabilities, [:teacher_name, :day_of_week]
    
    # 보충수업 사용 제한 (월별 횟수 제한 등)
    create_table :makeup_quotas do |t|
      t.references :user, null: false, foreign_key: true
      t.integer :year
      t.integer :month
      t.integer :used_count, default: 0
      t.integer :max_count, default: 2 # 월 최대 2회
      
      t.timestamps
    end
    
    add_index :makeup_quotas, [:user_id, :year, :month], unique: true
  end
end
