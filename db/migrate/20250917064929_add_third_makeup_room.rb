class AddThirdMakeupRoom < ActiveRecord::Migration[8.0]
  def change
    # 목요일/금요일 전용 3번 보충수업 방 추가
    # 프로덕션 스키마에 맞춰 필요한 컬럼만 사용
    MakeupRoom.create!(
      number: 3,
      capacity: 1,
      has_outlet: true
    )
  end
end
