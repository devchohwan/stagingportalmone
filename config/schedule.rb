# Use this file to easily define all of your cron jobs.
#
# It's helpful, but not entirely necessary to understand cron before proceeding.
# http://en.wikipedia.org/wiki/Cron

# 로그 파일 설정
set :output, "#{path}/log/cron.log"

# 매시간 정각에 수업 차감 작업 실행 (각 수업 종료 시각에 차감)
every 1.hour do
  rake "lessons:deduct_hourly"
end

# Learn more: http://github.com/javan/whenever
