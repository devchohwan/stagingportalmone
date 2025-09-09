class PrepareForProductionDataImport < ActiveRecord::Migration[8.0]
  def up
    # PostgreSQL에서 SQLite로 마이그레이션하기 위한 스키마 조정
    
    # 1. makeup_reservations 테이블의 기본 상태를 'pending'으로 변경 (PostgreSQL과 동일)
    change_column_default :makeup_reservations, :status, 'pending'
    
    # 2. users 테이블 인덱스 추가 (성능 최적화)
    add_index :users, :username, unique: true, if_not_exists: true
    add_index :users, :email, if_not_exists: true
    add_index :users, :status, if_not_exists: true
    
    # 3. reservations 테이블 인덱스 추가
    add_index :reservations, [:user_id, :start_time], if_not_exists: true
    add_index :reservations, [:room_id, :start_time], if_not_exists: true
    add_index :reservations, :status, if_not_exists: true
    
    # 4. makeup_reservations 테이블 인덱스 추가
    add_index :makeup_reservations, [:user_id, :start_time], if_not_exists: true
    add_index :makeup_reservations, [:makeup_room_id, :start_time], if_not_exists: true
    add_index :makeup_reservations, :status, if_not_exists: true
    
    # 5. penalties 테이블 인덱스 추가
    add_index :penalties, [:user_id, :year, :month], unique: true, if_not_exists: true
    
    # 6. phone_verifications 테이블 인덱스 추가
    add_index :phone_verifications, :phone, if_not_exists: true
    add_index :phone_verifications, :expires_at, if_not_exists: true
    
    # 7. rooms 테이블 인덱스 추가
    add_index :rooms, :number, unique: true, if_not_exists: true
    
    # 8. makeup_rooms 테이블 인덱스 추가
    add_index :makeup_rooms, :number, unique: true, if_not_exists: true
    
    puts "Schema prepared for production data import"
    puts "Current tables: #{ActiveRecord::Base.connection.tables.sort}"
  end
  
  def down
    # 인덱스 제거는 하지 않음 (성능상 유지하는 것이 좋음)
    change_column_default :makeup_reservations, :status, 'active'
    puts "Reverted to development schema defaults"
  end
end
