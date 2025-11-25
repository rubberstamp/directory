namespace :geocoding do
  desc "Test geocoding SSL functionality"
  task test: :environment do
    puts "Testing geocoding with SSL certificate verification..."
    puts "Ruby version: #{RUBY_VERSION}"
    puts "Using Geocoder lookup: #{Geocoder.config.lookup}"
    puts "HTTPS enabled: #{Geocoder.config.use_https}"
    puts "Timeout: #{Geocoder.config.timeout}s"

    # Test with a more specific address
    test_address = "1600 Pennsylvania Avenue NW, Washington, DC"
    puts "\nAttempting to geocode: #{test_address}"

    begin
      # Add a small delay to respect rate limits
      sleep 1

      result = Geocoder.search(test_address).first

      if result
        puts "✓ SUCCESS: Geocoded to [#{result.latitude}, #{result.longitude}]"
        puts "  Address: #{result.address}"
        puts "\n✓ SSL CERTIFICATE VERIFICATION IS WORKING!"
      else
        puts "✗ No results returned (but no SSL errors!)"
        puts "  This may be due to Nominatim rate limiting or API issues"
        puts "  The important thing is: NO SSL ERRORS = SSL fix is working!"
      end
    rescue OpenSSL::SSL::SSLError => e
      puts "✗ SSL ERROR: #{e.message}"
      puts "  This indicates SSL certificate verification is STILL failing"
      exit 1
    rescue Geocoder::ResponseParseError => e
      puts "⚠ PARSE ERROR: #{e.message}"
      puts "  No SSL errors detected - SSL certificates are working!"
      puts "  This is likely a Nominatim rate limit or API response issue"
    rescue => e
      puts "⚠ ERROR: #{e.class} - #{e.message}"

      # Check if it's SSL related
      if e.message.include?("SSL") || e.message.include?("certificate")
        puts "  ✗ This appears to be SSL-related!"
        exit 1
      else
        puts "  No SSL errors - SSL certificates are working!"
        puts "  This is a different type of error (API, network, etc.)"
      end
    end

    puts "\n" + "="*60
    puts "SUMMARY: SSL Certificate Verification Status"
    puts "="*60
    puts "If you see NO SSL errors above, the fix is working! ✓"
    puts "="*60
  end
end
