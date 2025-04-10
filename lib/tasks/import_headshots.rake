require "open-uri"
require "fileutils"
require "net/http"
require "mini_magick"

namespace :headshots do
  desc "Download headshots from Google Drive links and store them locally"
  task import: :environment do
    # Ensure storage directory exists
    storage_dir = Rails.root.join("public", "uploads", "headshots")
    FileUtils.mkdir_p(storage_dir) unless Dir.exist?(storage_dir)

    # Find profiles with Google Drive headshot URLs
    profiles_with_drive_links = Profile.where("headshot_url LIKE ?", "%drive.google.com%")

    puts "Found #{profiles_with_drive_links.count} profiles with Google Drive headshot links"

    success_count = 0
    error_count = 0

    profiles_with_drive_links.each do |profile|
      begin
        puts "Processing headshot for #{profile.name}..."
        file_id = extract_file_id(profile.headshot_url)

        if file_id.present?
          # Try multiple approaches to download the image
          downloaded = false

          # Approach 1: Export as JPEG (works for many Google Drive images)
          direct_url = "https://drive.google.com/uc?export=download&id=#{file_id}"

          # Create a filename based on profile name and file ID (for uniqueness)
          filename = "#{profile.name.parameterize}-#{file_id}.jpg"
          local_path = File.join(storage_dir, filename)

          # Try primary methods
          methods = [
            { name: "Direct download", url: direct_url },
            { name: "Thumbnail", url: "https://drive.google.com/thumbnail?id=#{file_id}&sz=w1000" },
            { name: "Export as JPEG", url: "https://drive.google.com/thumbnail?id=#{file_id}&sz=w1000-h1000" }
          ]

          methods.each do |method|
            puts "  Trying: #{method[:name]}"
            if download_file(method[:url], local_path)
              # Update the profile with the new local URL
              new_url = "/uploads/headshots/#{filename}"
              profile.update(headshot_url: new_url)

              puts "  ✓ Success with #{method[:name]}"
              downloaded = true
              success_count += 1
              break
            end
          end

          # If none of the direct methods worked and we have a API key, try API-based methods
          if !downloaded && ENV["GOOGLE_API_KEY"].present?
            puts "  Trying API-based methods..."
            api_url = "https://www.googleapis.com/drive/v3/files/#{file_id}?alt=media&key=#{ENV['GOOGLE_API_KEY']}"

            if download_file(api_url, local_path)
              new_url = "/uploads/headshots/#{filename}"
              profile.update(headshot_url: new_url)

              puts "  ✓ Success with API method"
              downloaded = true
              success_count += 1
            end
          end

          # If all else fails, create a placeholder avatar
          if !downloaded
            puts "  ! Could not download image, creating placeholder avatar instead"
            name = CGI.escape(profile.name)
            placeholder_url = "https://ui-avatars.com/api/?name=#{name}&background=random&color=fff&size=200"
            profile.update(headshot_url: placeholder_url)
            puts "  ✓ Created placeholder avatar for #{profile.name}"
            error_count += 1
          end
        else
          puts "  ! Could not extract file ID from URL for #{profile.name}: #{profile.headshot_url}"
          error_count += 1
        end
      rescue StandardError => e
        puts "  ! Error processing profile #{profile.name}: #{e.message}"
        error_count += 1
      end
    end

    puts "\nHeadshot import completed."
    puts "Successes: #{success_count}"
    puts "Fallbacks to placeholder avatars: #{error_count}"
    puts "\nRun 'rails headshots:report' to see the current status of all profile images."
  end

  desc "Generate a report of headshot status for all profiles"
  task report: :environment do
    total = Profile.count
    with_headshots = Profile.where.not(headshot_url: nil).count
    with_placeholders = Profile.where("headshot_url LIKE ?", "%ui-avatars.com%").count
    with_local = Profile.where("headshot_url LIKE ?", "/uploads/headshots/%").count
    with_google_drive = Profile.where("headshot_url LIKE ?", "%drive.google.com%").count
    with_external = Profile.where("headshot_url LIKE ?", "http%").count - with_placeholders - with_google_drive

    puts "\n====== HEADSHOT STATUS REPORT ======"
    puts "Total profiles: #{total}"
    puts "Profiles with headshots: #{with_headshots} (#{(with_headshots.to_f / total * 100).round(1)}%)"
    puts "  - Local images: #{with_local}"
    puts "  - Google Drive links (unprocessed): #{with_google_drive}"
    puts "  - Placeholder avatars: #{with_placeholders}"
    puts "  - Other external sources: #{with_external}"
    puts "Profiles without any headshot: #{total - with_headshots}"
    puts "===================================="
  end

  # Helper method to extract Google Drive file ID from various URL formats
  def extract_file_id(url)
    return nil unless url.present?

    # Format: https://drive.google.com/open?id=FILE_ID
    if url.include?("open?id=")
      match = url.match(/id=([a-zA-Z0-9_-]+)/)
      return match[1] if match && match[1].present?
    end

    # Format: https://drive.google.com/file/d/FILE_ID/view
    if url.include?("/file/d/")
      match = url.match(/\/file\/d\/([a-zA-Z0-9_-]+)/)
      return match[1] if match && match[1].present?
    end

    # Format: https://drive.google.com/uc?id=FILE_ID
    if url.include?("uc?id=")
      match = url.match(/id=([a-zA-Z0-9_-]+)/)
      return match[1] if match && match[1].present?
    end

    # Format: https://docs.google.com/uc?id=FILE_ID
    if url.include?("docs.google.com/uc?id=")
      match = url.match(/id=([a-zA-Z0-9_-]+)/)
      return match[1] if match && match[1].present?
    end

    # Format: https://drive.google.com/drive/folders/FILE_ID
    if url.include?("/drive/folders/")
      match = url.match(/\/drive\/folders\/([a-zA-Z0-9_-]+)/)
      return match[1] if match && match[1].present?
    end

    nil
  end

  # Helper method to download a file with error handling and retries
  def download_file(url, local_path, max_retries = 3)
    retries = 0

    begin
      # Download the file with a user agent to simulate a browser
      downloaded_file = URI.open(
        url,
        "User-Agent" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/100.0.4896.127 Safari/537.36",
        "Accept" => "image/avif,image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8",
        read_timeout: 10
      )

      # Check if the downloaded content is actually an image
      content_type = downloaded_file.meta["content-type"]

      if content_type && content_type.start_with?("text/html")
        puts "    Error: Received HTML instead of an image."
        return false
      end

      # Save the downloaded file
      File.open(local_path, "wb") do |file|
        file.write(downloaded_file.read)
      end

      # Verify the file was saved, has content, and is a valid image
      if File.exist?(local_path) && File.size(local_path) > 0
        begin
          # Try to process with MiniMagick to verify it's a valid image
          image = MiniMagick::Image.open(local_path)

          # Resize if the image is too large
          if image.width > 1000 || image.height > 1000
            image.resize "1000x1000>"
            image.write local_path
          end

          # Optionally convert to a specific format and quality
          image.format "jpg"
          image.quality 85
          image.write local_path

          true
        rescue MiniMagick::Invalid => e
          puts "    Error: Downloaded file is not a valid image: #{e.message}"
          File.delete(local_path) if File.exist?(local_path)
          false
        end
      else
        puts "    Error: Downloaded file is empty or doesn't exist."
        false
      end
    rescue OpenURI::HTTPError => e
      puts "    HTTP Error downloading file: #{e.message}"

      if retries < max_retries
        retries += 1
        puts "    Retrying download (#{retries}/#{max_retries})..."
        sleep 1
        retry
      end

      false
    rescue StandardError => e
      puts "    Error downloading file: #{e.message}"

      if retries < max_retries
        retries += 1
        puts "    Retrying download (#{retries}/#{max_retries})..."
        sleep 1
        retry
      end

      false
    end
  end
end
