class ImportPracticeData < ActiveRecord::Migration[8.0]
  def up
    require 'sqlite3'
    
    # Practice DB 연결
    practice_db = SQLite3::Database.new(Rails.root.join('storage', 'practice_backup_20250905.sqlite3'))
    
    puts "=== Practice 데이터 가져오기 시작 ==="
    
    # 사용자 데이터 가져오기
    import_users(practice_db)
    
    # 다른 테이블들도 필요시 추가
    # import_reservations(practice_db)
    # import_penalties(practice_db)
    
    practice_db.close
    puts "=== Practice 데이터 가져오기 완료 ==="
  end
  
  def down
    # 가져온 데이터 삭제 (필요시)
    puts "Import rollback - manual cleanup required"
  end
  
  private
  
  def import_users(practice_db)
    puts "사용자 데이터 가져오기..."
    
    practice_db.execute("SELECT * FROM users") do |row|
      # 컴럼 순서: id, username, name, email, phone, password_digest, status, is_admin, teacher, created_at, updated_at
      
      # 이미 존재하는 사용자는 스킵 (username 기준)
      existing_user = User.find_by(username: row[1])
      if existing_user
        puts "사용자 #{row[1]} 이미 존재함 - 스킵"
        next
      end
      
      begin
        user = User.create!(
          username: row[1],
          name: row[2],
          email: row[3],
          phone: row[4],
          password_digest: row[5], # 비밀번호 그대로 유지!
          status: row[6] || 'pending',
          is_admin: row[7] || false,
          teacher: row[8],
          created_at: row[9] ? DateTime.parse(row[9]) : Time.current,
          updated_at: row[10] ? DateTime.parse(row[10]) : Time.current
        )
        puts "사용자 생성됨: #{user.username} (#{user.name})"
      rescue => e
        puts "사용자 생성 실패 #{row[1]}: #{e.message}"
      end
    end
  end
  
  # 필요시 다른 테이블들도 추가
  def import_reservations(practice_db)
    puts "예약 데이터 가져오기..."
    # 예약 데이터 가져오기 로직
  end
  
  def import_penalties(practice_db)
    puts "페널티 데이터 가져오기..."
    # 페널티 데이터 가져오기 로직  
  end
end
