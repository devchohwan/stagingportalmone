#!/usr/bin/env ruby
require 'pg'

# 로컬 PostgreSQL 연결
local_conn = PG.connect(
  host: 'localhost',
  port: 5432,
  dbname: 'portal_monemusic',
  user: 'monemusic',
  password: '5dnjfdjr1!'
)

# 서버 PostgreSQL 연결 (Docker 컨테이너 내부)
server_conn = PG.connect(
  host: '115.68.195.125',
  port: 5432,
  dbname: 'monemusic_production',
  user: 'monemusic',
  password: 'monemusic2024!'
)

puts "=== 서버로 데이터 전송 시작 ==="

# Rooms 전송
puts "\n1. Rooms 데이터 전송..."
room_count = 0
local_conn.exec("SELECT * FROM rooms").each do |row|
  begin
    server_conn.exec_params(
      "INSERT INTO rooms (id, name, capacity, description, created_at, updated_at, number, has_outlet)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
       ON CONFLICT (id) DO UPDATE SET
         name = EXCLUDED.name,
         capacity = EXCLUDED.capacity,
         description = EXCLUDED.description,
         number = EXCLUDED.number",
      [
        row['id'],
        row['name'],
        row['capacity'],
        row['description'],
        row['created_at'],
        row['updated_at'],
        row['number'],
        row['has_outlet']
      ]
    )
    room_count += 1
  rescue => e
    puts "Room #{row['id']} 전송 실패: #{e.message}"
  end
end
puts "Rooms 전송 완료: #{room_count}개"

# Reservations 전송
puts "\n2. Reservations 데이터 전송..."
reservation_count = 0
local_conn.exec("SELECT * FROM reservations").each do |row|
  begin
    server_conn.exec_params(
      "INSERT INTO reservations (id, user_id, room_id, start_time, end_time, status, created_at, updated_at, cancelled_by)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
       ON CONFLICT (id) DO NOTHING",
      [
        row['id'],
        row['user_id'],
        row['room_id'],
        row['start_time'],
        row['end_time'],
        row['status'],
        row['created_at'],
        row['updated_at'],
        row['cancelled_by']
      ]
    )
    reservation_count += 1
  rescue => e
    puts "Reservation #{row['id']} 전송 실패: #{e.message}"
  end
end
puts "Reservations 전송 완료: #{reservation_count}개"

# Penalties 전송
puts "\n3. Penalties 데이터 전송..."
penalty_count = 0
local_conn.exec("SELECT * FROM penalties").each do |row|
  begin
    server_conn.exec_params(
      "INSERT INTO penalties (id, user_id, month, year, no_show_count, cancel_count, is_blocked, created_at, updated_at)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
       ON CONFLICT (id) DO UPDATE SET
         no_show_count = EXCLUDED.no_show_count,
         cancel_count = EXCLUDED.cancel_count,
         is_blocked = EXCLUDED.is_blocked",
      [
        row['id'],
        row['user_id'],
        row['month'],
        row['year'],
        row['no_show_count'],
        row['cancel_count'],
        row['is_blocked'],
        row['created_at'],
        row['updated_at']
      ]
    )
    penalty_count += 1
  rescue => e
    puts "Penalty #{row['id']} 전송 실패: #{e.message}"
  end
end
puts "Penalties 전송 완료: #{penalty_count}개"

# 시퀀스 업데이트
['rooms', 'reservations', 'penalties'].each do |table|
  max_id = server_conn.exec("SELECT COALESCE(MAX(id), 0) FROM #{table}").first['coalesce'].to_i
  server_conn.exec("SELECT setval('#{table}_id_seq', #{max_id + 1}, false)")
end

# 최종 확인
puts "\n=== 서버 데이터 최종 확인 ==="
puts "Rooms: #{server_conn.exec('SELECT COUNT(*) FROM rooms').first['count']}개"
puts "Reservations: #{server_conn.exec('SELECT COUNT(*) FROM reservations').first['count']}개"  
puts "Penalties: #{server_conn.exec('SELECT COUNT(*) FROM penalties').first['count']}개"
puts "Users: #{server_conn.exec('SELECT COUNT(*) FROM users').first['count']}명"

local_conn.close
server_conn.close
puts "\n전송 완료!"