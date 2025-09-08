class MakeupBase < ActiveRecord::Base
  self.abstract_class = true
  
  # 통합 데이터베이스 사용 (Portal과 동일한 DB - PostgreSQL)
  # ApplicationRecord의 연결을 사용하도록 변경
  # establish_connection은 제거하고 기본 연결 사용
  
  # 시간대를 서울로 설정
  def self.default_timezone
    :local
  end
end