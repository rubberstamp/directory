namespace :geocoding do
  desc "Test geocoding SSL functionality"
  task test: :environment do
    puts "Testing geocoding with SSL certificate verification..."
    puts "Ruby version: #{RUBY_VERSION}"
    puts "Using Geocoder lookup: #{Geocoder.config.lookup}"
    puts "HTTPS enabled: #{Geocoder.config.use_https}"

    test_address = "New York, NY"
    puts "\nAttempting to geocode: #{test_address}"

    begin
      result = Geocoder.search(test_address).first

      if result
        puts "✓ SUCCESS: Geocoded to [#{result.latitude}, #{result.longitude}]"
        puts "  Address: #{result.address}"
      else
        puts "✗ FAILED: No results returned"
      end
    rescue OpenSSL::SSL::SSLError => e
      puts "✗ SSL ERROR: #{e.message}"
      puts "  This indicates SSL certificate verification is failing"
    rescue => e
      puts "✗ ERROR: #{e.class} - #{e.message}"
      puts "  Backtrace:"
      puts e.backtrace.first(5).map { |line| "    #{line}" }.join("\n")
    end
  end
end
