# Managing Profile Headshots

The guest list data contains links to headshot images stored on Google Drive. To make these images reliably available within the application, we've provided several methods to process these links and manage headshot images.

## Admin Interface

The easiest way to manage headshots is through the admin interface:

1. Go to Admin → Headshots
2. The dashboard shows the current status of all profile images
3. You can process Google Drive links in bulk, or handle individual profiles

The admin interface provides:
- Real-time status overview
- Ability to upload images directly
- Option to generate placeholder avatars
- Batch processing tools

## Automated Methods

### Option 1: Import from Google Drive (Recommended)

This approach attempts to download the images directly from Google Drive and store them locally:

```bash
# Running via web interface (recommended)
Visit /admin/headshots and click "Start Import"

# Or via command line
GOOGLE_API_KEY=your_api_key rails headshots:from_google_drive_api
```

For best results:
- Add a Google API key to your environment (get one from the [Google Cloud Console](https://console.cloud.google.com/apis/credentials))
- Make sure the public/uploads/headshots directory exists and is writable

### Option 2: Find Profile Photos Using Clearbit

This approach uses the Clearbit API to find profile photos based on email addresses:

```bash
# Try to find and download photos via Clearbit
rails headshots:from_clearbit
```

### Option 3: Generate Placeholder Avatars

If the above methods don't work, you can generate placeholder avatars based on the person's initials:

```bash
rails headshots:generate_placeholders
```

This creates avatars using the UI Avatars service, which generates initial-based colorful avatars.

## Manual Methods

### Manual Upload Through Admin Interface

1. Go to Admin → Headshots
2. Find the profile you want to update
3. Click "Upload"
4. Choose an image file from your computer or enter a URL
5. Click "Save"

### Batch Image Download

For a completely manual approach, you can view all the Google Drive links:

```bash
# View the list of profiles with Google Drive links and instructions
rails headshots:instructions
```

## Technical Details

### Image Storage

The imported images are stored in:
- `/public/uploads/headshots/` directory
- Served as static content by the Rails app
- Profile records are updated to point to these local paths

### Image Processing

When images are imported or uploaded, they are processed to:
- Resize large images to a maximum of 1000x1000 pixels
- Convert to JPEG format for consistent quality
- Apply consistent quality settings (85% quality)
- Validate image integrity

### Placeholder Avatars

For profiles without proper headshots, placeholder avatars:
- Use the person's initials to create a unique, recognizable image
- Generate a different background color for each person
- Are provided by the UI Avatars service (no local storage required)
- Example URL: `https://ui-avatars.com/api/?name=John+Doe&background=random`

### Google Drive URL Formats

The system handles many different Google Drive URL formats:
- `https://drive.google.com/open?id=FILE_ID`
- `https://drive.google.com/file/d/FILE_ID/view`
- `https://drive.google.com/uc?id=FILE_ID`
- `https://docs.google.com/uc?id=FILE_ID`
- `https://drive.google.com/drive/folders/FILE_ID`

## Troubleshooting

- **Permission Issues**: Some Google Drive links may still require authentication. In these cases, the system falls back to generating placeholder avatars.
- **Image Size Issues**: If an image is too large to process, try downloading it manually and resizing it before uploading.
- **Failed Imports**: You can run the import task again at any time. It will only process profiles that still have Google Drive links.
- **Missing API Key**: For best results with the Google Drive API method, add a GOOGLE_API_KEY to your environment variables.

## Development

The headshot management system uses:
- MiniMagick gem for image processing
- Kaminari gem for pagination in the admin interface
- Google Drive API for authenticated image access (optional)