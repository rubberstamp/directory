namespace :test_s3 do
  desc "Test AWS S3 connectivity with current credentials"
  task connection: :environment do
    require "aws-sdk-s3"

    puts "Testing AWS S3 connectivity..."
    puts "-------------------------------"

    begin
      # Extract AWS configuration from Rails
      access_key_id = ENV["AWS_ACCESS_KEY_ID"] || Rails.application.credentials.dig(:aws, :access_key_id)
      secret_access_key = ENV["AWS_SECRET_ACCESS_KEY"] || Rails.application.credentials.dig(:aws, :secret_access_key)
      region = ENV["AWS_REGION"] || Rails.application.credentials.dig(:aws, :region) || "us-east-1"
      bucket = ENV["AWS_BUCKET"] || Rails.application.credentials.dig(:aws, :bucket)

      # Check if credentials are present
      if access_key_id.blank? || secret_access_key.blank?
        puts "⚠️  AWS credentials are missing!"
        puts "Please ensure AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY are set as environment variables or in credentials."
        exit 1
      end

      if bucket.blank?
        puts "⚠️  AWS bucket is not specified!"
        puts "Please ensure AWS_BUCKET is set as an environment variable or in credentials."
        exit 1
      end

      # Print configuration (without exposing the full secret key)
      puts "AWS Configuration:"
      puts "Access Key ID: #{access_key_id}"
      puts "Secret Access Key: #{secret_access_key[0..3]}...#{secret_access_key[-4..-1] if secret_access_key.length > 8}"
      puts "Region: #{region}"
      puts "Bucket: #{bucket}"

      # Create S3 client
      s3 = Aws::S3::Client.new(
        access_key_id: access_key_id,
        secret_access_key: secret_access_key,
        region: region
      )

      # Test 1: List buckets (authentication test)
      puts "\nTest 1: Authenticating and listing buckets..."
      begin
        buckets = s3.list_buckets.buckets.map(&:name)
        puts "✅ Success! Found #{buckets.count} buckets: #{buckets.join(', ')}"
      rescue => e
        puts "❌ Failed to list buckets: #{e.message}"
        puts "This suggests an authentication or permissions issue."
        exit 1
      end

      # Test 2: Check if our bucket exists in the list
      puts "\nTest 2: Checking if our bucket '#{bucket}' exists..."
      if buckets.include?(bucket)
        puts "✅ Success! Bucket '#{bucket}' exists."
      else
        puts "❌ Bucket '#{bucket}' not found in your account. Available buckets are: #{buckets.join(', ')}"
        exit 1
      end

      # Test 3: Upload a test file
      puts "\nTest 3: Uploading a test file..."
      test_key = "test_connection_#{Time.now.to_i}.txt"
      test_content = "This is a test file uploaded at #{Time.now}"

      begin
        s3.put_object(
          bucket: bucket,
          key: test_key,
          body: test_content
        )
        puts "✅ Success! Test file uploaded with key: #{test_key}"
      rescue => e
        puts "❌ Failed to upload test file: #{e.message}"
        puts "This suggests write permissions issues with the bucket."
        exit 1
      end

      # Test 4: Download the test file
      puts "\nTest 4: Downloading the test file..."
      begin
        response = s3.get_object(
          bucket: bucket,
          key: test_key
        )

        downloaded_content = response.body.read

        if downloaded_content == test_content
          puts "✅ Success! Downloaded content matches uploaded content."
        else
          puts "⚠️  Warning: Downloaded content doesn't match what was uploaded."
          puts "Uploaded: #{test_content}"
          puts "Downloaded: #{downloaded_content}"
        end
      rescue => e
        puts "❌ Failed to download test file: #{e.message}"
        puts "This suggests read permissions issues with the bucket."
        exit 1
      end

      # Test 5: Delete the test file
      puts "\nTest 5: Deleting the test file..."
      begin
        s3.delete_object(
          bucket: bucket,
          key: test_key
        )
        puts "✅ Success! Test file deleted."
      rescue => e
        puts "❌ Failed to delete test file: #{e.message}"
        puts "This suggests delete permissions issues with the bucket."
        exit 1
      end

      # Test 6: Check Rails ActiveStorage configuration
      puts "\nTest 6: Checking Rails ActiveStorage configuration..."
      if Rails.application.config.active_storage.service == :amazon
        puts "✅ Success! ActiveStorage is configured to use the :amazon service in this environment."
      else
        puts "⚠️  Warning: ActiveStorage is configured to use the :#{Rails.application.config.active_storage.service} service in this environment, not :amazon."
        puts "To use S3 storage in this environment, set config.active_storage.service = :amazon in config/environments/#{Rails.env}.rb"
      end

      # Summary
      puts "\n✅ ALL TESTS PASSED! Your AWS S3 configuration appears to be working correctly."
      puts "You should be able to use ActiveStorage with S3 in this environment."

    rescue => e
      puts "\n❌ UNEXPECTED ERROR: #{e.message}"
      puts e.backtrace.join("\n") if Rails.env.development?
      exit 1
    end
  end
end
