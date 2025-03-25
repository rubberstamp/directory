require 'fileutils'
require 'uri'
require 'net/http'
require 'json'
require 'mini_magick'

namespace :headshots do
  desc 'Download headshots from Google Drive using the API'
  task from_google_drive_api: :environment do
    # Check for required environment variables
    unless ENV['GOOGLE_API_KEY']
      puts "Error: GOOGLE_API_KEY environment variable is required."
      puts "Please set it with: export GOOGLE_API_KEY=your_api_key"
      puts "You can get an API key from the Google Cloud Console:"
      puts "https://console.cloud.google.com/apis/credentials"
      exit 1
    end

    # Ensure storage directory exists
    storage_dir = Rails.root.join('public', 'uploads', 'headshots')
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
          # Create a filename based on profile name and file ID (for uniqueness)
          filename = "#{profile.name.parameterize}-#{file_id}.jpg"
          local_path = File.join(storage_dir, filename)
          
          # First get file metadata to check if it's publicly accessible
          metadata_url = URI("https://www.googleapis.com/drive/v3/files/#{file_id}?key=#{ENV['GOOGLE_API_KEY']}")
          
          metadata_response = Net::HTTP.get_response(metadata_url)
          if metadata_response.is_a?(Net::HTTPSuccess)
            file_data = JSON.parse(metadata_response.body)
            
            # Check if the file is publicly accessible or restricted
            if file_data['shared'] && file_data['capabilities'] && file_data['capabilities']['canDownload']
              puts "  ✓ File is publicly accessible"
              
              # Try to download using the API
              api_url = "https://www.googleapis.com/drive/v3/files/#{file_id}?alt=media&key=#{ENV['GOOGLE_API_KEY']}"
              
              if download_file(api_url, local_path)
                # Update the profile with the new local URL
                new_url = "/uploads/headshots/#{filename}"
                profile.update(headshot_url: new_url)
                
                puts "  ✓ Successfully downloaded with Google Drive API"
                success_count += 1
              else
                puts "  ! Failed to download with API, trying alternative methods"
                
                # Try alternative methods if API download fails
                alternative_methods = [
                  { name: "Direct download", url: "https://drive.google.com/uc?export=download&id=#{file_id}" },
                  { name: "Thumbnail large", url: "https://drive.google.com/thumbnail?id=#{file_id}&sz=w1000" },
                  { name: "Thumbnail medium", url: "https://drive.google.com/thumbnail?id=#{file_id}&sz=w500" }
                ]
                
                downloaded = false
                alternative_methods.each do |method|
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
                
                # If all methods fail, create a placeholder avatar
                if !downloaded
                  puts "  ! Could not download image, creating placeholder avatar instead"
                  name = CGI.escape(profile.name)
                  placeholder_url = "https://ui-avatars.com/api/?name=#{name}&background=random&color=fff&size=200"
                  profile.update(headshot_url: placeholder_url)
                  puts "  ✓ Created placeholder avatar for #{profile.name}"
                  error_count += 1
                end
              end
            else
              puts "  ! File is not publicly accessible, trying alternative methods"
              
              # Try alternative methods for non-public files
              alternative_methods = [
                { name: "Thumbnail large", url: "https://drive.google.com/thumbnail?id=#{file_id}&sz=w1000" },
                { name: "Thumbnail medium", url: "https://drive.google.com/thumbnail?id=#{file_id}&sz=w500" }
              ]
              
              downloaded = false
              alternative_methods.each do |method|
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
              
              # If all methods fail, create a placeholder avatar
              if !downloaded
                puts "  ! Could not download image, creating placeholder avatar instead"
                name = CGI.escape(profile.name)
                placeholder_url = "https://ui-avatars.com/api/?name=#{name}&background=random&color=fff&size=200"
                profile.update(headshot_url: placeholder_url)
                puts "  ✓ Created placeholder avatar for #{profile.name}"
                error_count += 1
              end
            end
          else
            puts "  ! Failed to get file metadata: #{metadata_response.code} - #{metadata_response.message}"
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
    
    puts "\nGoogle Drive headshot import completed."
    puts "Successes: #{success_count} / #{profiles_with_drive_links.count}"
    puts "Fallbacks to placeholder avatars: #{error_count} / #{profiles_with_drive_links.count}"
    puts "\nRun 'rails headshots:report' to see the current status of all profile images."
  end

  # Helper method to extract Google Drive file ID from various URL formats
  def extract_file_id(url)
    return nil unless url.present?
    
    # Format: https://drive.google.com/open?id=FILE_ID
    if url.include?('open?id=')
      match = url.match(/id=([a-zA-Z0-9_-]+)/)
      return match[1] if match && match[1].present?
    end
    
    # Format: https://drive.google.com/file/d/FILE_ID/view
    if url.include?('/file/d/')
      match = url.match(/\/file\/d\/([a-zA-Z0-9_-]+)/)
      return match[1] if match && match[1].present?
    end
    
    # Format: https://drive.google.com/uc?id=FILE_ID
    if url.include?('uc?id=')
      match = url.match(/id=([a-zA-Z0-9_-]+)/)
      return match[1] if match && match[1].present?
    end
    
    # Format: https://docs.google.com/uc?id=FILE_ID
    if url.include?('docs.google.com/uc?id=')
      match = url.match(/id=([a-zA-Z0-9_-]+)/)
      return match[1] if match && match[1].present?
    end
    
    # Format: https://drive.google.com/drive/folders/FILE_ID
    if url.include?('/drive/folders/')
      match = url.match(/\/drive\/folders\/([a-zA-Z0-9_-]+)/)
      return match[1] if match && match[1].present?
    end

    nil
  end
  
  # Helper method to download a file with error handling and retries
  def download_file(url, local_path, max_retries = 3)
    retries = 0
    
    begin
      # First check if URL is accessible
      uri = URI(url)
      request = Net::HTTP::Get.new(uri)
      request["User-Agent"] = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/100.0.4896.127 Safari/537.36"
      request["Accept"] = "image/avif,image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8"
      
      response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == "https") do |http|
        http.request(request)
      end
      
      unless response.is_a?(Net::HTTPSuccess)
        puts "    HTTP Error: #{response.code} - #{response.message}"
        return false
      end
      
      # Check content type to ensure it's an image
      content_type = response["content-type"]
      if content_type && content_type.start_with?('text/html')
        puts "    Error: Received HTML instead of an image."
        return false
      end
      
      # Download and save the file
      File.open(local_path, 'wb') do |file|
        file.write(response.body)
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
          
          return true
        rescue MiniMagick::Invalid => e
          puts "    Error: Downloaded file is not a valid image: #{e.message}"
          File.delete(local_path) if File.exist?(local_path)
          return false
        end
      else
        puts "    Error: Downloaded file is empty or doesn't exist."
        return false
      end
    rescue StandardError => e
      puts "    Error downloading file: #{e.message}"
      
      if retries < max_retries
        retries += 1
        puts "    Retrying download (#{retries}/#{max_retries})..."
        sleep 1
        retry
      end
      
      return false
    end
  end
end