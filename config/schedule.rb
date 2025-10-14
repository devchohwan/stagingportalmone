# Use this file to easily define all of your cron jobs.
#
# It's helpful, but not entirely necessary to understand cron before proceeding.
# http://en.wikipedia.org/wiki/Cron

# 로그 파일 설정
set :output, "#{path}/log/cron.log"

# 수업 종료 시각(13~22시 정각)에 수업 차감 작업 실행
['13:00', '14:00', '15:00', '16:00', '17:00', '18:00', '19:00', '20:00', '21:00', '22:00'].each do |time|
  every :day, at: time do
    rake "lessons:deduct_hourly"
  end
end

# Learn more: http://github.com/javan/whenever
