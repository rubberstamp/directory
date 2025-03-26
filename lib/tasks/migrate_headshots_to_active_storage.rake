require 'open-uri'

namespace :headshots do
  desc 'Migrate existing headshots from URL-based storage to ActiveStorage'
  task migrate_to_active_storage: :environment do
    # Find profiles with headshot URLs but no ActiveStorage attachment
    profiles_to_migrate = Profile.left_joins(headshot_attachment: :blob)
                                .where.not(headshot_url: nil)
                                .where("active_storage_attachments.id IS NULL")
                                .where.not("headshot_url LIKE ?", "%ui-avatars.com%") # Skip placeholder avatars
    
    puts "Found #{profiles_to_migrate.count} profiles with headshots to migrate to ActiveStorage"
    
    success_count = 0
    error_count = 0
    
    profiles_to_migrate.find_each do |profile|
      begin
        puts "Migrating headshot for #{profile.name}..."
        url = profile.headshot_url
        
        # Skip URLs from external domains we can't easily download
        if url.start_with?("http") && !url.include?("drive.google.com")
          begin
            # Download the file
            downloaded_file = URI.open(
              url,
              "User-Agent" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/100.0.4896.127 Safari/537.36",
              "Accept" => "image/avif,image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8",
              read_timeout: 10
            )
            
            # Check if it's an image
            content_type = downloaded_file.meta["content-type"]
            if content_type && !content_type.start_with?('text/html')
              # Generate filename
              filename = File.basename(url)
              if filename.blank? || filename == '/'
                filename = "#{profile.name.parameterize}-headshot.jpg"
              end
              
              # Attach to ActiveStorage
              profile.headshot.attach(
                io: downloaded_file,
                filename: filename,
                content_type: content_type
              )
              
              puts "  ✓ Successfully migrated to ActiveStorage"
              success_count += 1
            else
              puts "  ! Downloaded content is not an image"
              error_count += 1
            end
          rescue StandardError => e
            puts "  ! Error downloading from URL: #{e.message}"
            error_count += 1
          end
        # Handle local files
        elsif url.start_with?("/uploads/headshots/")
          begin
            # Find the file on disk
            local_path = Rails.root.join("public#{url}")
            
            if File.exist?(local_path)
              filename = File.basename(url)
              
              # Attach to ActiveStorage
              profile.headshot.attach(
                io: File.open(local_path),
                filename: filename,
                content_type: 'image/jpeg'
              )
              
              puts "  ✓ Successfully migrated local file to ActiveStorage"
              success_count += 1
            else
              puts "  ! Local file not found: #{local_path}"
              error_count += 1
            end
          rescue StandardError => e
            puts "  ! Error processing local file: #{e.message}"
            error_count += 1
          end
        # Skip Google Drive URLs for now
        elsif url.include?("drive.google.com")
          puts "  ! Google Drive URLs will be handled separately"
          error_count += 1
        else
          puts "  ! Unsupported URL format: #{url}"
          error_count += 1
        end
      rescue StandardError => e
        puts "  ! Error processing profile #{profile.name}: #{e.message}"
        error_count += 1
      end
    end
    
    puts "\nHeadshot migration completed."
    puts "Successes: #{success_count}"
    puts "Failures: #{error_count}"
    puts "Total migrated: #{ActiveStorage::Attachment.where(record_type: 'Profile', name: 'headshot').count}"
  end

  desc 'Import Google Drive headshots to ActiveStorage'
  task import_google_drive_to_active_storage: :environment do
    # This task uses the Google Drive API to import headshots
    # It requires a Google API key to be set in the environment
    unless ENV['GOOGLE_API_KEY'].present?
      puts "ERROR: GOOGLE_API_KEY environment variable is required for this task"
      exit 1
    end
    
    # Find profiles with Google Drive headshot URLs but no ActiveStorage attachment
    profiles_to_migrate = Profile.left_joins(headshot_attachment: :blob)
                                .where("headshot_url LIKE ?", "%drive.google.com%")
                                .where("active_storage_attachments.id IS NULL")
    
    puts "Found #{profiles_to_migrate.count} profiles with Google Drive headshots to migrate"
    
    success_count = 0
    error_count = 0
    
    profiles_to_migrate.find_each do |profile|
      begin
        puts "Processing Google Drive headshot for #{profile.name}..."
        
        # Extract file ID from the Google Drive URL
        file_id = nil
        url = profile.headshot_url
        
        # Format: https://drive.google.com/open?id=FILE_ID
        if url.include?('open?id=')
          match = url.match(/id=([a-zA-Z0-9_-]+)/)
          file_id = match[1] if match && match[1].present?
        end
        
        # Format: https://drive.google.com/file/d/FILE_ID/view
        if file_id.nil? && url.include?('/file/d/')
          match = url.match(/\/file\/d\/([a-zA-Z0-9_-]+)/)
          file_id = match[1] if match && match[1].present?
        end
        
        # Additional URL formats
        if file_id.nil? && url.include?('uc?id=')
          match = url.match(/id=([a-zA-Z0-9_-]+)/)
          file_id = match[1] if match && match[1].present?
        end
        
        if file_id.present?
          # Try to download using Google API
          api_url = "https://www.googleapis.com/drive/v3/files/#{file_id}?alt=media&key=#{ENV['GOOGLE_API_KEY']}"
          
          begin
            # Download the file
            downloaded_file = URI.open(
              api_url,
              "User-Agent" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/100.0.4896.127 Safari/537.36",
              read_timeout: 30
            )
            
            # Attach to ActiveStorage
            profile.headshot.attach(
              io: downloaded_file,
              filename: "#{profile.name.parameterize}-#{file_id}.jpg",
              content_type: 'image/jpeg'
            )
            
            puts "  ✓ Successfully imported Google Drive image to ActiveStorage"
            success_count += 1
          rescue StandardError => e
            puts "  ! Error downloading from Google Drive API: #{e.message}"
            
            # Try alternative method with thumbnail API
            begin
              thumbnail_url = "https://drive.google.com/thumbnail?id=#{file_id}&sz=w1000-h1000"
              
              downloaded_file = URI.open(
                thumbnail_url,
                "User-Agent" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/100.0.4896.127 Safari/537.36",
                read_timeout: 10
              )
              
              profile.headshot.attach(
                io: downloaded_file,
                filename: "#{profile.name.parameterize}-#{file_id}.jpg",
                content_type: 'image/jpeg'
              )
              
              puts "  ✓ Successfully imported Google Drive thumbnail to ActiveStorage"
              success_count += 1
            rescue StandardError => e
              puts "  ! Error with fallback method: #{e.message}"
              error_count += 1
            end
          end
        else
          puts "  ! Could not extract file ID from Google Drive URL: #{url}"
          error_count += 1
        end
      rescue StandardError => e
        puts "  ! Error processing profile #{profile.name}: #{e.message}"
        error_count += 1
      end
    end
    
    puts "\nGoogle Drive headshot migration completed."
    puts "Successes: #{success_count}"
    puts "Failures: #{error_count}"
  end
end