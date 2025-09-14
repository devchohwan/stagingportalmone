namespace :users do
  desc "Update specific user status to pending"
  task update_status_to_pending: :environment do
    # 정혜연 사용자를 pending 상태로 변경
    user = User.find_by(username: 'starhyjung')
    
    if user
      puts "Found user: #{user.name} (#{user.username})"
      puts "Current status: #{user.status}"
      
      user.status = 'pending'
      
      if user.save
        puts "Successfully updated status to: #{user.status}"
      else
        puts "Failed to update status: #{user.errors.full_messages.join(', ')}"
      end
    else
      puts "User 'starhyjung' not found"
      
      # 이름으로 검색 시도
      users_by_name = User.where("name LIKE ?", "%정혜연%")
      if users_by_name.any?
        puts "Found users with name '정혜연':"
        users_by_name.each do |u|
          puts "  - #{u.name} (#{u.username}) - Status: #{u.status}"
        end
      end
    end
    
    # 현재 pending 상태인 사용자들 출력
    puts "\nCurrent pending users:"
    User.pending.each do |u|
      puts "  - #{u.name} (#{u.username})"
    end
  end
end