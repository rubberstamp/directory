require "uri"
require "net/http"
require "json"
require "fileutils"

namespace :headshots do
  desc "Find headshots using Clearbit API based on email addresses"
  task from_clearbit: :environment do
    # Ensure storage directory exists
    storage_dir = Rails.root.join("public", "uploads", "headshots")
    FileUtils.mkdir_p(storage_dir) unless Dir.exist?(storage_dir)

    # Find profiles with placeholder avatars
    profiles = Profile.where("headshot_url LIKE ?", "%ui-avatars.com%")

    puts "Found #{profiles.count} profiles with placeholder avatars"
    puts "Looking for headshots via Clearbit..."

    success_count = 0

    profiles.each do |profile|
      # Skip if the email is a placeholder
      next if profile.email.include?("example.com")

      puts "Processing #{profile.name} (#{profile.email})..."

      # Try to get an image from Clearbit
      image_url = get_clearbit_image(profile.email)

      if image_url
        # Download the image
        filename = "#{profile.name.parameterize}-clearbit.jpg"
        local_path = File.join(storage_dir, filename)

        if download_image(image_url, local_path)
          # Update the profile with the new local URL
          new_url = "/uploads/headshots/#{filename}"
          profile.update(headshot_url: new_url)

          puts "✅ Successfully downloaded headshot for #{profile.name}"
          success_count += 1
        else
          puts "❌ Failed to download image for #{profile.name}"
        end
      else
        puts "❌ No Clearbit image found for #{profile.name}"
      end
    end

    puts "\nHeadshot import completed. Found photos for #{success_count} out of #{profiles.count} profiles."

    # Alternative options if some profiles failed
    if success_count < profiles.count
      remaining = profiles.count - success_count

      puts "\nOptions for the remaining #{remaining} profiles:"
      puts "1. Use other services like Gravatar: rails headshots:from_gravatar"
      puts "2. Use LinkedIn's People API with a premium account"
      puts "3. Manually download images from LinkedIn, Twitter, etc."
    end
  end

  desc "Generate Gravatar images for profiles"
  task from_gravatar: :environment do
    # Ensure storage directory exists
    storage_dir = Rails.root.join("public", "uploads", "headshots")
    FileUtils.mkdir_p(storage_dir) unless Dir.exist?(storage_dir)

    # Find profiles with placeholder avatars
    profiles = Profile.where("headshot_url LIKE ?", "%ui-avatars.com%")

    puts "Found #{profiles.count} profiles with placeholder avatars"
    puts "Looking for headshots via Gravatar..."

    success_count = 0

    profiles.each do |profile|
      # Skip if the email is a placeholder
      next if profile.email.include?("example.com")

      puts "Processing #{profile.name} (#{profile.email})..."

      # Get Gravatar URL
      gravatar_url = get_gravatar_url(profile.email)

      # Download and verify it's not the default Gravatar
      filename = "#{profile.name.parameterize}-gravatar.jpg"
      local_path = File.join(storage_dir, filename)

      if download_image(gravatar_url, local_path)
        # Check if it's not the default Gravatar by size
        # Default Gravatars are usually very small files
        if File.size(local_path) > 1000 # If larger than 1KB, probably not default
          # Update the profile with the new local URL
          new_url = "/uploads/headshots/#{filename}"
          profile.update(headshot_url: new_url)

          puts "✅ Successfully downloaded Gravatar for #{profile.name}"
          success_count += 1
        else
          # Delete the file and continue
          File.delete(local_path)
          puts "❌ Default Gravatar detected for #{profile.name}, skipping"
        end
      else
        puts "❌ Failed to download Gravatar for #{profile.name}"
      end
    end

    puts "\nGravatar import completed. Found photos for #{success_count} out of #{profiles.count} profiles."
  end

  private

  # Get profile image from Clearbit API
  def get_clearbit_image(email)
    return nil unless email.present?

    # Use Clearbit's Logo API to get a person's image
    # Note: This doesn't require an API key for basic usage!
    url = "https://person.clearbit.com/v1/people/email/#{URI.encode_www_form_component(email)}"

    begin
      uri = URI(url)
      request = Net::HTTP::Get.new(uri)
      request["User-Agent"] = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36"

      response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
        http.request(request)
      end

      if response.code == "200"
        data = JSON.parse(response.body)
        return data["avatar"] if data["avatar"].present?
      else
        puts "  Clearbit API error: #{response.code} - #{response.message}"
      end
    rescue StandardError => e
      puts "  Error querying Clearbit API: #{e.message}"
    end

    nil
  end

  # Generate Gravatar URL from email
  def get_gravatar_url(email)
    require "digest/md5"
    hash = Digest::MD5.hexdigest(email.strip.downcase)
    "https://www.gravatar.com/avatar/#{hash}?s=200&d=404"
  end

  # Download an image file
  def download_image(url, local_path)
    begin
      # Download the image
      uri = URI(url)
      response = Net::HTTP.get_response(uri)

      unless response.is_a?(Net::HTTPSuccess)
        puts "  HTTP Error: #{response.code} - #{response.message}"
        return false
      end

      # Save the downloaded file
      File.open(local_path, "wb") do |file|
        file.write(response.body)
      end

      # Verify the file was saved and has content
      if File.exist?(local_path) && File.size(local_path) > 0
        true
      else
        puts "  Error: Downloaded file is empty or doesn't exist."
        false
      end
    rescue StandardError => e
      puts "  Error downloading image: #{e.message}"
      false
    end
  end
end
