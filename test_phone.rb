#!/usr/bin/env ruby
require 'httparty'
require 'json'

# 먼저 로그인
login_response = HTTParty.post(
  "http://localhost:3000/api/v1/auth/login",
  body: {
    username: "zaltair93",
    password: "test123"  # 실제 비밀번호로 변경 필요
  }.to_json,
  headers: { 'Content-Type' => 'application/json' }
)

if login_response.success?
  data = JSON.parse(login_response.body)
  token = data['token']
  user = data['user']
  
  puts "=== Login Response ==="
  puts "Token: #{token ? 'Present' : 'Missing'}"
  puts "User data: #{user.inspect}"
  puts "Phone in login response: #{user['phone']}"
  puts ""
  
  # 연습실 API 테스트
  puts "=== Testing Practice API ==="
  practice_response = HTTParty.get(
    "http://localhost:3000/api/v1/users/profile",
    headers: {
      'Authorization' => "Bearer #{token}",
      'Content-Type' => 'application/json'
    }
  )
  puts "Status: #{practice_response.code}"
  puts "Response: #{practice_response.body}"
  puts ""
  
  # 보충수업 API 테스트
  puts "=== Testing Makeup API ==="
  makeup_response = HTTParty.get(
    "http://localhost:3002/api/v1/users/profile",
    headers: {
      'Authorization' => "Bearer #{token}",
      'Content-Type' => 'application/json'
    }
  )
  puts "Status: #{makeup_response.code}"
  puts "Response: #{makeup_response.body}"
  puts ""
  
  # 모네뮤직 사용자 API 테스트
  puts "=== Testing Monemusic User API ==="
  monemusic_response = HTTParty.get(
    "http://localhost:3000/api/v1/users/zaltair93",
    headers: {
      'Authorization' => "Bearer #{token}",
      'Content-Type' => 'application/json'
    }
  )
  puts "Status: #{monemusic_response.code}"
  puts "Response: #{monemusic_response.body}"
  
else
  puts "Login failed: #{login_response.body}"
end