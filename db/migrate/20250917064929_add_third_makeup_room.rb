class AddThirdMakeupRoom < ActiveRecord::Migration[8.0]
  def change
    # 목요일/금요일 전용 3번 보충수업 방 추가
    MakeupRoom.create!(
      name: '연습실 3',
      number: 3,
      description: '연습실 3번 (목/금 전용)',
      has_outlet: true,
      is_active: true
    )
  end
end
