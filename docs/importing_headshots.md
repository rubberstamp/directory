# Managing Profile Headshots

This document describes how headshots are handled in the application, including the transition from URL-based storage to ActiveStorage.

## Overview

The application has transitioned from storing headshot images as URLs to using Rails ActiveStorage. This change provides better file management, variant generation, and cloud storage options.

### Current Storage Methods

1. **ActiveStorage (Recommended)**: Files uploaded through the admin interface are now stored using ActiveStorage
2. **Legacy URL Storage**: Older profiles may still use URL-based storage, pointing to:
   - Local files in `/public/uploads/headshots/`
   - Google Drive links
   - Placeholder avatars from ui-avatars.com

## Admin Interface

The easiest way to manage headshots is through the admin interface:

1. Go to Admin → Headshots
2. The dashboard shows the current status of all profile images
3. You can upload new images directly (using ActiveStorage)
4. You can still process existing Google Drive links or generate placeholder avatars

The admin interface provides:
- Real-time status overview
- Ability to upload images directly using ActiveStorage
- Option to generate placeholder avatars
- Migration status tracking

## Migrating to ActiveStorage

A rake task is provided to migrate legacy headshots to ActiveStorage:

```bash
# Migrate local headshots to ActiveStorage
rails headshots:migrate_to_active_storage

# Import Google Drive headshots to ActiveStorage (requires Google API key)
GOOGLE_API_KEY=your_key_here rails headshots:import_google_drive_to_active_storage
```

## Legacy Methods

The following methods are still supported but considered legacy:

### Legacy: Import from Google Drive

This approach downloads images from Google Drive and stores them locally:

```bash
# Running via web interface
Visit /admin/headshots and click "Start Import"

# Or via command line
GOOGLE_API_KEY=your_api_key rails headshots:from_google_drive_api
```

### Legacy: Find Profile Photos Using Clearbit

This approach uses the Clearbit API to find profile photos based on email addresses:

```bash
# Try to find and download photos via Clearbit
rails headshots:from_clearbit
```

### Legacy: Generate Placeholder Avatars

```bash
rails headshots:generate_placeholders
```

This creates avatars using the UI Avatars service, which generates initial-based colorful avatars.

## Displaying Headshots

The application supports both ActiveStorage and legacy URL headshots through the `headshot_url_or_attached` method:

```ruby
# In models/profile.rb
def headshot_url_or_attached
  return Rails.application.routes.url_helpers.rails_blob_path(headshot, only_path: true) if headshot.attached?
  headshot_url
end
```

In views, you can use this method or check for attached headshots directly:

```erb
<% if profile.headshot.attached? %>
  <%= image_tag profile.headshot, alt: profile.name, class: "..." %>
<% elsif profile.headshot_url.present? %>
  <img src="<%= profile.headshot_url %>" alt="<%= profile.name %>" class="...">
<% else %>
  <!-- Fallback content for profiles without headshots -->
<% end %>
```

## Image Processing with ActiveStorage

When using ActiveStorage, you can generate variants using the image_processing gem:

```erb
<!-- Original image -->
<%= image_tag profile.headshot %>

<!-- Resized thumbnail -->
<%= image_tag profile.headshot.variant(resize_to_limit: [100, 100]) %>

<!-- Cropped to square -->
<%= image_tag profile.headshot.variant(resize_to_fill: [100, 100]) %>
```

## Technical Details

### ActiveStorage Configuration

ActiveStorage is configured in `config/storage.yml`:

```yaml
# Local storage (default in development)
local:
  service: Disk
  root: <%= Rails.root.join("storage") %>

# For production, consider using a cloud provider
# amazon:
#   service: S3
#   access_key_id: <%= Rails.application.credentials.dig(:aws, :access_key_id) %>
#   secret_access_key: <%= Rails.application.credentials.dig(:aws, :secret_access_key) %>
#   region: us-east-1
#   bucket: your_bucket_name
```

To use a specific service, set it in the environment config:

```ruby
# config/environments/production.rb
config.active_storage.service = :amazon
```

### Legacy Image Storage

Legacy images are still stored in:
- `/public/uploads/headshots/` directory
- Served as static content by the Rails app
- Profile records with legacy headshots have a `headshot_url` that points to these paths

### Placeholder Avatars

For profiles without proper headshots, placeholder avatars:
- Use the person's initials to create a unique, recognizable image
- Generate a different background color for each person
- Are provided by the UI Avatars service (no local storage required)
- Example URL: `https://ui-avatars.com/api/?name=John+Doe&background=random`

## Best Practices

1. Always use ActiveStorage for new uploads
2. Run the migration tasks to convert legacy URLs to ActiveStorage
3. Use image variants for different display sizes rather than storing multiple copies
4. For production, consider using a cloud storage provider for better scalability

## Development

The headshot management system uses:
- ActiveStorage for modern file storage
- MiniMagick gem for legacy image processing
- Google Drive API for authenticated image access (optional for migration)