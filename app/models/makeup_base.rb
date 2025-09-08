class MakeupBase < ActiveRecord::Base
  self.abstract_class = true
  
  # 통합 데이터베이스 사용 (Portal과 동일한 DB)
  establish_connection(
    adapter: 'sqlite3',
    database: Rails.root.join('storage/development.sqlite3').to_s,
    pool: 5,
    timeout: 5000
  )
  
  # 시간대를 서울로 설정
  def self.default_timezone
    :local
  end
end