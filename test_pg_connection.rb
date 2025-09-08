require 'pg'

begin
  conn = PG.connect(
    host: '115.68.195.125',
    port: 5432,
    dbname: 'monemusic_production',
    user: 'monemusic',
    password: 'monemusic2024!'
  )
  puts "PostgreSQL 연결 성공!"
  result = conn.exec("SELECT version();")
  puts "PostgreSQL 버전: #{result.first['version']}"
  conn.close
rescue PG::Error => e
  puts "연결 실패: #{e.message}"
end
