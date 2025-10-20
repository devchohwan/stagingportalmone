# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

teachers_data = [
  { username: 'teacher_otto', name: '오또 선생님', teacher_name: '오또', phone: '01012345678' },
  { username: 'teacher_museong', name: '무성 선생님', teacher_name: '무성', phone: '01012345679' },
  { username: 'teacher_seonggyun', name: '성균 선생님', teacher_name: '성균', phone: '01012345680' },
  { username: 'teacher_noname', name: '노네임 선생님', teacher_name: '노네임', phone: '01012345681' },
  { username: 'teacher_rohan', name: '로한 선생님', teacher_name: '로한', phone: '01012345682' },
  { username: 'teacher_beomseok', name: '범석 선생님', teacher_name: '범석', phone: '01012345683' },
  { username: 'teacher_dubak', name: '두박 선생님', teacher_name: '두박', phone: '01012345684' },
  { username: 'teacher_jimyeong', name: '지명 선생님', teacher_name: '지명', phone: '01012345685' },
  { username: 'teacher_dohyun', name: '도현 선생님', teacher_name: '도현', phone: '01012345686' }
]

teachers_data.each do |teacher_data|
  User.find_or_create_by!(username: teacher_data[:username]) do |user|
    user.name = teacher_data[:name]
    user.teacher_name = teacher_data[:teacher_name]
    user.phone = teacher_data[:phone]
    user.password = 'teacher1234'
    user.is_admin = true
    user.sms_enabled = true
    user.status = 'active'
  end
end

puts "✅ #{teachers_data.size}명의 선생님 계정이 생성되었습니다."
