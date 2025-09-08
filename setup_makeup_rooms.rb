#!/usr/bin/env ruby
require 'pg'

# PostgreSQL 연결
pg_conn = PG.connect(
  host: 'localhost',
  port: 5432,
  dbname: 'portal_monemusic',
  user: 'monemusic',
  password: '5dnjfdjr1!'
)

puts "=== 보충수업 방 설정 ==="

# 기존 연습실 방 (ID 3-8) 관련 예약 먼저 삭제
puts "방 3-8 관련 예약 삭제 중..."
pg_conn.exec("DELETE FROM reservations WHERE room_id > 2")

# 기존 연습실 방 (ID 3-8) 삭제
puts "연습실 방 3-8 삭제 중..."
pg_conn.exec("DELETE FROM rooms WHERE id > 2")

# 보충수업 방 2개만 유지/업데이트
puts "보충수업 방 설정 중..."

# Room 1
pg_conn.exec_params(
  "UPDATE rooms SET name = $1, description = $2, capacity = $3, number = $4 WHERE id = 1",
  ['보충수업실 1', '보충수업 전용 교실 1', 1, 1]
)

# Room 2  
pg_conn.exec_params(
  "UPDATE rooms SET name = $1, description = $2, capacity = $3, number = $4 WHERE id = 2",
  ['보충수업실 2', '보충수업 전용 교실 2', 1, 2]
)

# 시퀀스 리셋
pg_conn.exec("SELECT setval('rooms_id_seq', 2, true)")

# 최종 확인
result = pg_conn.exec("SELECT id, name, number FROM rooms ORDER BY id")
puts "\n=== 최종 방 목록 ==="
result.each do |row|
  puts "ID: #{row['id']}, 이름: #{row['name']}, 번호: #{row['number']}"
end

puts "\n완료!"
pg_conn.close