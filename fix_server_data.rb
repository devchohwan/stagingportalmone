#!/usr/bin/env ruby
require 'pg'
require 'sqlite3'

# 서버 PostgreSQL 연결
server_conn = PG.connect(
  host: '115.68.195.125',
  port: 5432,
  dbname: 'monemusic_production',
  user: 'monemusic',
  password: 'monemusic2024!'
)

# SQLite 백업 파일 (원본 데이터)
sqlite_db = SQLite3::Database.new('storage/practice_backup_20250905.sqlite3')
sqlite_db.results_as_hash = true

puts "=== 서버 데이터 수정 시작 ==="

# 1. 기존 데이터 클리어
puts "\n1. 기존 데이터 클리어..."
server_conn.exec("DELETE FROM reservations")
server_conn.exec("DELETE FROM rooms")
puts "기존 데이터 삭제 완료"

# 2. 연습실 8개 설정
puts "\n2. 연습실 8개 설정..."
room_count = 0
(1..8).each do |i|
  server_conn.exec_params(
    "INSERT INTO rooms (id, name, capacity, description, created_at, updated_at, number, has_outlet)
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8)",
    [
      i,
      "연습실 #{i}",
      4,
      "연습실 #{i}번",
      Time.now,
      Time.now,
      i,
      true
    ]
  )
  room_count += 1
end
puts "연습실 #{room_count}개 생성 완료"

# 3. 모든 예약 데이터 전송 (127개)
puts "\n3. 예약 데이터 전송..."
reservation_count = 0
sqlite_db.execute("SELECT * FROM reservations") do |row|
  begin
    # date와 시간을 합쳐서 timestamp 생성
    start_datetime = row['date'] && row['start_time'] ? "#{row['date']} #{row['start_time']}" : nil
    end_datetime = row['date'] && row['end_time'] ? "#{row['date']} #{row['end_time']}" : nil
    
    # user_id가 서버에 있는지 확인
    user_exists = server_conn.exec_params("SELECT COUNT(*) FROM users WHERE id = $1", [row['user_id']]).first['count'].to_i
    if user_exists == 0
      puts "User #{row['user_id']} 없음 - 예약 #{row['id']} 건너뜀"
      next
    end
    
    # room_id가 1-8 범위인지 확인
    if row['room_id'].to_i < 1 || row['room_id'].to_i > 8
      puts "Room #{row['room_id']} 범위 초과 - 예약 #{row['id']} 건너뜀"
      next
    end
    
    server_conn.exec_params(
      "INSERT INTO reservations (id, user_id, room_id, start_time, end_time, status, created_at, updated_at)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8)",
      [
        row['id'],
        row['user_id'],
        row['room_id'],
        start_datetime,
        end_datetime,
        row['status'] || 'pending',
        row['created_at'] || Time.now.to_s,
        row['updated_at'] || Time.now.to_s
      ]
    )
    reservation_count += 1
  rescue => e
    puts "Reservation #{row['id']} 전송 실패: #{e.message}"
  end
end
puts "예약 #{reservation_count}개 전송 완료"

# 4. 시퀀스 업데이트
['rooms', 'reservations'].each do |table|
  max_id = server_conn.exec("SELECT COALESCE(MAX(id), 0) FROM #{table}").first['coalesce'].to_i
  server_conn.exec("SELECT setval('#{table}_id_seq', #{max_id + 1}, false)")
end

# 최종 확인
puts "\n=== 서버 최종 데이터 ==="
puts "연습실: #{server_conn.exec('SELECT COUNT(*) FROM rooms').first['count']}개"
puts "예약: #{server_conn.exec('SELECT COUNT(*) FROM reservations').first['count']}개"
puts "페널티: #{server_conn.exec('SELECT COUNT(*) FROM penalties').first['count']}개"
puts "회원: #{server_conn.exec('SELECT COUNT(*) FROM users').first['count']}명"

sqlite_db.close
server_conn.close
puts "\n완료!"