# Migrating Legacy Headshots to ActiveStorage

This document outlines the process for migrating existing URL-based headshots to ActiveStorage in this Rails application.

## Background

The application initially stored headshot URLs directly in the `Profile` model's `headshot_url` field. We've now implemented ActiveStorage for better file handling and to support direct uploads.

## Migration Process

We've created a Rake task to automate the migration process. This task:

1. Identifies profiles with legacy headshot URLs
2. Downloads each image from the URL
3. Attaches the downloaded image to the profile using ActiveStorage
4. Preserves the original URL for backward compatibility

## Running the Migration

To migrate all legacy headshots to ActiveStorage:

```bash
bundle exec rake headshots:migrate_to_active_storage
```

This task is also automatically run during deployment via the `deployment:prepare` Rake task.

## Implementation Details

The migration task is implemented in `lib/tasks/migrate_headshots_to_active_storage.rake`:

```ruby
namespace :headshots do
  desc "Migrate headshots from URLs to ActiveStorage"
  task migrate_to_active_storage: :environment do
    require 'down'
    
    # Make sure ActiveStorage is available and configured
    unless defined?(ActiveStorage)
      puts "ActiveStorage not available, skipping migration."
      next
    end
    
    puts "Starting headshot migration from URLs to ActiveStorage..."
    
    # Find profiles with headshot_url but no ActiveStorage attachment
    profiles_count = Profile.where.not(headshot_url: [nil, '']).count
    migrated_count = 0
    
    Profile.where.not(headshot_url: [nil, '']).find_each do |profile|
      # Skip profiles that already have an ActiveStorage headshot
      if profile.headshot.attached?
        puts "Profile ##{profile.id} already has an attached ActiveStorage headshot, skipping."
        migrated_count += 1
        next
      end
      
      begin
        # Convert relative URLs to absolute if needed
        url = profile.headshot_url
        url = "https://directory.fly.dev#{url}" if url.start_with?('/')
        
        # Download the image
        puts "Downloading headshot from #{url} for Profile ##{profile.id}"
        tempfile = Down.download(url)
        
        # Use the original filename or create one from the profile
        filename = File.basename(url)
        if filename.blank? || filename == '/'
          # Create a filename from the profile name
          extension = File.extname(url).presence || '.jpg'
          filename = "#{profile.name.parameterize}-#{Time.now.to_i}#{extension}"
        end
        
        # Attach the downloaded file to the profile
        profile.headshot.attach(
          io: tempfile,
          filename: filename,
          content_type: tempfile.content_type || 'image/jpeg'
        )
        
        puts "Successfully attached headshot for Profile ##{profile.id}"
        migrated_count += 1
      rescue => e
        puts "Error migrating headshot for Profile ##{profile.id}: #{e.message}"
      end
    end
    
    puts "Headshot migration complete. Migrated #{migrated_count} of #{profiles_count} profiles."
  end
end
```

## Model Integration

The `Profile` model has been updated to support both ActiveStorage attachments and legacy URL-based headshots:

```ruby
class Profile < ApplicationRecord
  has_one_attached :headshot
  
  # Legacy headshot URL compatibility
  def headshot_url_or_attachment
    if headshot.attached?
      Rails.application.routes.url_helpers.rails_blob_url(headshot)
    else
      headshot_url.presence
    end
  end
  
  # For form display and uploads
  def headshot_url=(value)
    super unless value.is_a?(ActionDispatch::Http::UploadedFile)
  end
end
```

## Testing the Migration

After running the migration, you can verify the results:

```ruby
# Total profiles with headshot URLs
Profile.where.not(headshot_url: [nil, '']).count

# Profiles with ActiveStorage headshots
Profile.all.count { |p| p.headshot.attached? }

# Profiles that need migration
Profile.where.not(headshot_url: [nil, '']).count - Profile.all.count { |p| p.headshot.attached? }
```

## Manual Troubleshooting

If specific profiles fail to migrate, you can manually migrate them:

```ruby
profile = Profile.find(id)

# Download and attach the image
require 'down'
url = profile.headshot_url
tempfile = Down.download(url)
filename = File.basename(url).presence || "#{profile.name.parameterize}-#{Time.now.to_i}.jpg"

profile.headshot.attach(
  io: tempfile,
  filename: filename,
  content_type: tempfile.content_type || 'image/jpeg'
)
```

## AWS S3 Configuration

For production environments, ensure your AWS S3 bucket is properly configured:

1. Bucket policy allowing your IAM user/role
2. CORS configuration for direct uploads
3. Appropriate IAM permissions

See `docs/activestorage_s3_setup.md` for detailed AWS S3 configuration instructions.