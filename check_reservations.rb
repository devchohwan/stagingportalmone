require 'net/http'
require 'uri'

# Get CSRF token
uri = URI('http://localhost:3001/login')
response = Net::HTTP.get_response(uri)
csrf_token = response.body.match(/name="authenticity_token" value="([^"]+)"/)[1]
cookie = response['Set-Cookie']

# Login
uri = URI('http://localhost:3001/login')
http = Net::HTTP.new(uri.host, uri.port)
request = Net::HTTP::Post.new(uri.path)
request['Cookie'] = cookie
request['Content-Type'] = 'application/x-www-form-urlencoded'
request.body = URI.encode_www_form({
  'authenticity_token' => csrf_token,
  'username' => 'admin',
  'password' => 'ahsprla23221!'
})
response = http.request(request)

# Follow redirect and get session cookie
session_cookie = response['Set-Cookie']

# Access reservations page
uri = URI('http://localhost:3001/admin/reservations')
http = Net::HTTP.new(uri.host, uri.port)
request = Net::HTTP::Get.new(uri.path)
request['Cookie'] = session_cookie
response = http.request(request)

if response.code == '200'
  body = response.body.force_encoding('UTF-8')
  if body.include?('예약이 없습니다')
    puts 'Page shows: 예약이 없습니다'
  else
    # Extract reservation info
    reservations = body.scan(/<tr[^>]*>.*?<\/tr>/m).select { |row| row.include?('text-sm') && !row.include?('uppercase') }
    puts "Found #{reservations.size} reservation rows"
    if reservations.any?
      first = reservations.first
      # Parse user info
      if first =~ /<td[^>]*>\s*([^<]+)\s*<span/m
        puts "First reservation user: #{$1.strip}"
      end
      # Check for room info  
      if first =~ /(\d+)번/
        puts "Room number: #{$1}"
      end
    end
  end
else
  puts "Error: Got response code #{response.code}"
  puts "Redirect to: #{response['Location']}" if response['Location']
end