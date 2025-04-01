#!/usr/bin/env ruby
require 'uri'
require 'net/http'
require 'json'

# Get API key from environment
api_key = ENV['GOOGLE_API_KEY']
if api_key.nil? || api_key.empty?
  puts "Error: GOOGLE_API_KEY environment variable is not set or empty"
  exit 1
end

puts "API Key info:"
puts "- Length: #{api_key.length} characters"
puts "- Format check: #{api_key.match?(/^AIza[0-9A-Za-z\-_]{35}$/) ? 'Valid pattern' : 'Invalid pattern'}"
puts

# Test URL for Gemini API
url = URI("https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=#{api_key}")
http = Net::HTTP.new(url.host, url.port)
http.use_ssl = true

# Simple test request
request = Net::HTTP::Post.new(url)
request["Content-Type"] = "application/json"

request_body = {
  contents: [
    {
      parts: [
        {
          text: "Hello, please generate a brief response to confirm API access is working."
        }
      ]
    }
  ]
}

request.body = request_body.to_json

puts "Sending test request to Gemini API..."
response = http.request(request)

puts "Response status: #{response.code}"

# Display the response details
if response.code == "200"
  puts "SUCCESS! API request completed successfully!"
  response_data = JSON.parse(response.body)
  if response_data["candidates"] && !response_data["candidates"].empty?
    text = response_data["candidates"][0]["content"]["parts"][0]["text"]
    puts "\nResponse content: #{text[0..100]}..."
  else
    puts "\nResponse body: #{response.body[0..200]}..."
  end
else
  puts "ERROR: Request failed"
  puts "Response body: #{response.body}"
  
  # Try to extract and display the error message
  begin
    error_data = JSON.parse(response.body)
    if error_data["error"] && error_data["error"]["message"]
      puts "\nError message: #{error_data["error"]["message"]}"
    end
  rescue
    # If can't parse as JSON, just show the raw response
    puts "\nCould not parse error details"
  end
  
  # Provide troubleshooting steps based on error code
  case response.code
  when "400"
    puts "\nTroubleshooting for 400 error:"
    puts "- The API key format appears to be invalid"
    puts "- Ensure you've copied the full API key from Google Cloud Console"
    puts "- Verify that the API key is for the Gemini API specifically"
  when "403"
    puts "\nTroubleshooting for 403 error:"
    puts "- The API key may be valid but lacks permission to access Gemini API"
    puts "- Ensure the API key has the Gemini API enabled in its API restrictions"
    puts "- Check if the API key has been revoked or disabled"
    puts "- Verify quota limits have not been exceeded"
  when "404"
    puts "\nTroubleshooting for 404 error:"
    puts "- The API endpoint might be incorrect"
    puts "- Verify that the Gemini API is available in your region/project"
  else
    puts "\nGeneral troubleshooting:"
    puts "- Regenerate a new API key in the Google Cloud Console"
    puts "- Ensure the Vertex AI API and Gemini API are enabled for your project"
    puts "- Check for any quotas or limitations that might be affecting your access"
  end
end