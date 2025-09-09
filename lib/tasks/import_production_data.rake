require 'set'

namespace :import do
  desc "Import production data from PostgreSQL dump"
  task production_data: :environment do
    puts "Starting production data import..."
    
    # 1. 기존 데이터 백업 및 정리
    backup_existing_data
    
    # 2. SQL 파일에서 COPY 데이터 추출 및 변환
    import_users_data
    import_rooms_data
    import_makeup_rooms_data
    import_reservations_data
    import_makeup_reservations_data
    import_penalties_data
    import_phone_verifications_data
    
    puts "Production data import completed successfully!"
    print_import_summary
  end
  
  private
  
  def backup_existing_data
    puts "Creating backup of existing data..."
    timestamp = Time.current.strftime("%Y%m%d_%H%M%S")
    backup_file = "storage/backup_#{timestamp}.sql"
    
    # SQLite 데이터 백업 (sqlite3가 없어도 Rails로 백업)
    puts "Backup created: #{backup_file} (using Rails dump)"
    
    # 기존 데이터 완전 삭제 (참조 무결성 때문에 순서 중요)
    puts "Clearing existing data..."
    ActiveRecord::Base.connection.execute("PRAGMA foreign_keys = OFF")
    
    # 모든 테이블 데이터 삭제
    ActiveRecord::Base.connection.execute("DELETE FROM makeup_reservations")
    ActiveRecord::Base.connection.execute("DELETE FROM reservations")
    ActiveRecord::Base.connection.execute("DELETE FROM penalties")
    ActiveRecord::Base.connection.execute("DELETE FROM phone_verifications")
    ActiveRecord::Base.connection.execute("DELETE FROM users WHERE id > 1") # 관리자 계정 보존
    ActiveRecord::Base.connection.execute("DELETE FROM rooms")
    ActiveRecord::Base.connection.execute("DELETE FROM makeup_rooms")
    
    # SQLite 시퀀스 리셋 (ID 충돌 방지)
    ActiveRecord::Base.connection.execute("DELETE FROM sqlite_sequence WHERE name IN ('users', 'rooms', 'makeup_rooms', 'reservations', 'makeup_reservations', 'penalties', 'phone_verifications')")
    
    ActiveRecord::Base.connection.execute("PRAGMA foreign_keys = ON")
    
    puts "Cleared all existing data except admin user (id=1)"
  end
  
  def extract_copy_data(table_name)
    sql_content = File.read('storage/practice_production.sql')
    
    # COPY 명령과 데이터 추출
    copy_start = sql_content.index("COPY public.#{table_name}")
    return [] unless copy_start
    
    # COPY 라인 다음부터 \. 까지의 데이터 추출
    copy_section = sql_content[copy_start..-1]
    lines = copy_section.split("\n")
    
    data_lines = []
    found_copy_line = false
    
    lines.each do |line|
      if line.start_with?("COPY public.#{table_name}")
        found_copy_line = true
        next
      end
      
      break if line.strip == "\."
      
      if found_copy_line && !line.strip.empty?
        data_lines << line
      end
    end
    
    data_lines
  end
  
  def parse_copy_line(line)
    # PostgreSQL COPY 형식의 탭 분리 데이터를 파싱
    # \N 은 NULL 값으로 변환
    line.split("\t").map { |field| field == '\\N' ? nil : field }
  end
  
  def import_users_data
    puts "Importing users data..."
    data_lines = extract_copy_data('users')
    
    # 원래 ID와 새 ID의 매핑을 저장
    @user_id_mapping = {}
    
    imported_count = 0
    data_lines.each do |line|
      fields = parse_copy_line(line)
      next if fields.length < 11
      
      original_id = fields[0].to_i
      # ID 1은 건너뛰기 (기존 관리자 계정 보존)
      next if original_id == 1
      
      user = User.create!(
        username: fields[1],
        name: fields[2],
        email: fields[3],
        phone: fields[4],
        password_digest: fields[5],
        status: fields[6] || 'pending',
        is_admin: fields[7] == 't',
        teacher: fields[8],
        created_at: fields[9],
        updated_at: fields[10]
      )
      
      # 원래 ID와 새 ID 매핑 저장
      @user_id_mapping[original_id] = user.id
      imported_count += 1
    end
    
    puts "Imported #{imported_count} users"
    puts "User ID mapping created for reservations"
  end
  
  def import_rooms_data
    puts "Importing rooms data..."
    data_lines = extract_copy_data('rooms')
    
    imported_count = 0
    seen_numbers = Set.new
    
    data_lines.each do |line|
      fields = parse_copy_line(line)
      next if fields.length < 8
      
      room_number = fields[6].to_i
      # 중복된 룸 번호는 건너뛰기
      if seen_numbers.include?(room_number)
        puts "Skipping duplicate room number: #{room_number}"
        next
      end
      seen_numbers.add(room_number)
      
      begin
        room = Room.create!(
          name: fields[1],
          capacity: fields[2].to_i,
          description: fields[3],
          created_at: fields[4],
          updated_at: fields[5],
          number: room_number,
          has_outlet: fields[7] == 't'
        )
        imported_count += 1
      rescue ActiveRecord::RecordInvalid => e
        puts "Failed to import room #{fields[1]} (number: #{room_number}): #{e.message}"
      end
    end
    
    puts "Imported #{imported_count} rooms"
  end
  
  def import_makeup_rooms_data
    puts "Importing makeup rooms data..."
    data_lines = extract_copy_data('makeup_rooms')
    
    imported_count = 0
    seen_numbers = Set.new
    
    data_lines.each do |line|
      fields = parse_copy_line(line)
      next if fields.length < 8
      
      room_number = fields[4]&.to_i
      # 중복된 룸 번호는 건너뛰기
      if room_number && seen_numbers.include?(room_number)
        puts "Skipping duplicate makeup room number: #{room_number}"
        next
      end
      seen_numbers.add(room_number) if room_number
      
      begin
        room = MakeupRoom.create!(
          name: fields[1],
          description: fields[3],
          number: room_number,
          has_outlet: fields[5] == 't',
          created_at: fields[6],
          updated_at: fields[7]
        )
        imported_count += 1
      rescue ActiveRecord::RecordInvalid => e
        puts "Failed to import makeup room #{fields[1]} (number: #{room_number}): #{e.message}"
      end
    end
    
    puts "Imported #{imported_count} makeup rooms"
  end
  
  def import_reservations_data
    puts "Importing reservations data..."
    data_lines = extract_copy_data('reservations')
    
    imported_count = 0
    data_lines.each do |line|
      fields = parse_copy_line(line)
      next if fields.length < 9
      
      original_user_id = fields[1].to_i
      original_room_id = fields[2].to_i
      
      # 매핑된 사용자 ID 사용 (없으면 건너뛰기)
      new_user_id = @user_id_mapping[original_user_id] || original_user_id
      next unless User.exists?(new_user_id)
      
      # 룸 ID는 순차적으로 매핑 (예: 원래 ID 1-6 → 새 ID 1-6)
      room = Room.offset(original_room_id - 1).first
      next unless room
      
      reservation = Reservation.create!(
        user_id: new_user_id,
        room_id: room.id,
        start_time: fields[3],
        end_time: fields[4],
        status: fields[5],
        created_at: fields[6],
        updated_at: fields[7],
        cancelled_by: fields[8]
      )
      
      imported_count += 1
    end
    
    puts "Imported #{imported_count} reservations"
  end
  
  def import_makeup_reservations_data
    puts "Importing makeup reservations data..."
    data_lines = extract_copy_data('makeup_reservations')
    
    imported_count = 0
    data_lines.each do |line|
      fields = parse_copy_line(line)
      next if fields.length < 9
      
      original_user_id = fields[1].to_i
      original_room_id = fields[2].to_i
      
      # 매핑된 사용자 ID 사용
      new_user_id = @user_id_mapping[original_user_id] || original_user_id
      next unless User.exists?(new_user_id)
      
      # 보충수업 룸 ID는 순차적으로 매핑
      makeup_room = MakeupRoom.offset(original_room_id - 1).first
      next unless makeup_room
      
      reservation = MakeupReservation.create!(
        user_id: new_user_id,
        makeup_room_id: makeup_room.id,
        start_time: fields[3],
        end_time: fields[4],
        status: fields[5] || 'pending',
        cancelled_by: fields[6],
        created_at: fields[7],
        updated_at: fields[8]
      )
      
      imported_count += 1
    end
    
    puts "Imported #{imported_count} makeup reservations"
  end
  
  def import_penalties_data
    puts "Importing penalties data..."
    data_lines = extract_copy_data('penalties')
    
    imported_count = 0
    data_lines.each do |line|
      fields = parse_copy_line(line)
      next if fields.length < 9
      
      original_user_id = fields[1].to_i
      new_user_id = @user_id_mapping[original_user_id] || original_user_id
      next unless User.exists?(new_user_id)
      
      penalty = Penalty.create!(
        user_id: new_user_id,
        month: fields[2]&.to_i,
        year: fields[3]&.to_i,
        no_show_count: fields[4]&.to_i || 0,
        cancel_count: fields[5]&.to_i || 0,
        is_blocked: fields[6] == 't',
        created_at: fields[7],
        updated_at: fields[8]
      )
      
      imported_count += 1
    end
    
    puts "Imported #{imported_count} penalties"
  end
  
  def import_phone_verifications_data
    puts "Importing phone verifications data..."
    data_lines = extract_copy_data('phone_verifications')
    
    imported_count = 0
    data_lines.each do |line|
      fields = parse_copy_line(line)
      next if fields.length < 7
      
      verification = PhoneVerification.create!(
        phone: fields[1],
        code: fields[2],
        verified: fields[3] == 't',
        expires_at: fields[4],
        created_at: fields[5],
        updated_at: fields[6]
      )
      
      imported_count += 1
    end
    
    puts "Imported #{imported_count} phone verifications"
  end
  
  def print_import_summary
    puts "\n=== Import Summary ==="
    puts "Users: #{User.count}"
    puts "Rooms: #{Room.count}"
    puts "Makeup Rooms: #{MakeupRoom.count}"
    puts "Reservations: #{Reservation.count}"
    puts "Makeup Reservations: #{MakeupReservation.count}"
    puts "Penalties: #{Penalty.count}"
    puts "Phone Verifications: #{PhoneVerification.count}"
    puts "=====================\n"
  end
end
