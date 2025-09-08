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

# SQLite 백업 파일
sqlite_db = SQLite3::Database.new('storage/practice_backup_20250905.sqlite3')
sqlite_db.results_as_hash = true

puts "=== 예약 데이터 수정 시작 ==="

# 예약 데이터 업데이트
update_count = 0
sqlite_db.execute("SELECT * FROM reservations") do |row|
  begin
    # 서버에 해당 예약이 있는지 확인
    exists = server_conn.exec_params("SELECT COUNT(*) FROM reservations WHERE id = $1", [row['id']]).first['count'].to_i
    
    if exists > 0
      # 기존 예약 업데이트
      server_conn.exec_params(
        "UPDATE reservations SET start_time = $2, end_time = $3, status = $4 WHERE id = $1",
        [
          row['id'],
          row['start_time'],
          row['end_time'],
          row['status']
        ]
      )
      update_count += 1
    end
  rescue => e
    puts "Reservation #{row['id']} 업데이트 실패: #{e.message}"
  end
end

puts "예약 #{update_count}개 업데이트 완료"

# 최종 확인
puts "\n=== 업데이트 후 샘플 데이터 ==="
result = server_conn.exec("SELECT id, start_time, end_time, status FROM reservations LIMIT 5")
result.each do |row|
  puts "ID: #{row['id']}, Start: #{row['start_time']}, End: #{row['end_time']}, Status: #{row['status']}"
end

sqlite_db.close
server_conn.close
puts "\n완료!"