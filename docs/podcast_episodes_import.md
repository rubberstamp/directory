# Episode CSV Import and Export

This document explains how to import podcast episodes using the CSV import feature in the admin interface.

## Accessing the Import Feature

1. Log in to the admin dashboard
2. Navigate to Episodes (/admin/episodes)
3. Click the "Import CSV" button in the top right corner

## CSV Format

The CSV file should include the following columns:

| Column Name     | Required | Description                                   |
|-----------------|----------|-----------------------------------------------|
| Guest Name      | No       | Name of the primary guest for linking         |
| Episode Number  | Yes      | Unique identifier for the episode (integer)   |
| Episode Title   | Yes      | Title of the episode                          |
| Video ID        | Yes      | YouTube video ID or URL                       |
| Episode Date    | No       | Air date in YYYY-MM-DD format                 |
| Notes           | No       | Episode description or show notes             |
| Duration        | No       | Length in seconds                             |
| Thumbnail URL   | No       | URL to episode thumbnail image                |

You can download a template CSV by clicking the "Download template" link in the import modal.

## Import Options

- **Update existing episodes**: When checked, the system will attempt to match and update existing episodes using either YouTube Video ID or Episode Number. When unchecked, existing episodes will be skipped.

### Matching Logic

When updating existing episodes, the system uses the following logic:

1. First, it tries to find an exact match by YouTube Video ID
2. If no match is found by Video ID, it tries to find a match by Episode Number
3. If found by Episode Number, the Video ID will be updated to the one in the CSV
4. If a Video ID match is found but with a different Episode Number, the system will update the number only if it doesn't conflict with another episode
5. If an episode is found by both criteria but they point to different episodes, the Video ID match takes precedence

## How it Works

1. Upload your CSV file
2. The system validates the CSV format and required columns
3. Each row is processed:
   - For new episodes: A new episode record is created
   - For existing episodes: If "Update existing episodes" is checked, the episode is updated
   - Guest linking: If a guest name is provided, the system attempts to link the episode to that guest
4. After processing, a summary is displayed showing:
   - Number of episodes created
   - Number of episodes updated
   - Number of episodes skipped
   - Number of guests linked
   - Any errors that occurred

## Error Handling

If errors occur during import, they will be displayed in a modal. Common errors include:

- Missing required columns
- Invalid data formats
- Guest not found in the system
- Duplicate episode numbers (for new episodes)

## Video ID Format

The system accepts YouTube video IDs in the following formats:

- Plain 11-character ID (e.g., `abcd1234xyz`)
- Full YouTube URL (e.g., `https://www.youtube.com/watch?v=abcd1234xyz`)
- YouTube short URL (e.g., `https://youtu.be/abcd1234xyz`)
- Embed URL (e.g., `https://www.youtube.com/embed/abcd1234xyz`)

The system will extract the video ID from any of these formats.

## Guest Linking

When a guest name is provided, the system tries to find a matching profile by name (using a partial case-insensitive match). If found, that profile is linked to the episode as the primary guest.

## Exporting Episodes

You can export all episodes or a filtered subset to a CSV file for backup, analysis, or batch editing.

### How to Export Episodes

1. Navigate to the Episodes page in the admin dashboard (/admin/episodes)
2. (Optional) Enter search terms to filter the episodes
3. Click the "Export CSV" button
4. A CSV file will be downloaded with all episodes (or filtered episodes)

### Export Format

The exported CSV includes the same columns as the import format:
- Guest Name (the primary guest linked to the episode)
- Episode Number
- Episode Title
- Video ID
- Episode Date
- Notes
- Duration
- Thumbnail URL

### Using Exports for Batch Editing

1. Export your episodes
2. Open the CSV in a spreadsheet application
3. Make your changes
4. Save as CSV
5. Import the updated CSV with the "Update existing episodes" option checked

#### Common Batch Editing Scenarios

**Updating Multiple Episode Attributes:**
- Export all episodes
- Modify titles, dates, notes, etc. in the spreadsheet
- Re-import with "Update existing episodes" checked
- Episodes will be matched by their original YouTube ID or Episode Number

**Changing YouTube Links:**
- If you need to update YouTube links for episodes, use the Episode Number as the matching field
- Keep the Episode Number the same in your CSV
- Update the Video ID column
- Re-import with "Update existing episodes" checked
- The system will find the existing episode by number and update its video ID

**Re-numbering Episodes:**
- If you need to re-number episodes, use the YouTube ID as the matching field
- Keep the Video ID the same in your CSV
- Update the Episode Number column
- Re-import with "Update existing episodes" checked
- The system will find the existing episode by video ID and update its number (if the new number doesn't conflict)

This workflow is particularly useful for:
- Updating multiple episodes at once
- Correcting data across many episodes
- Adding missing information in bulk
- Standardizing titles or other fields

## Tips

- Prepare your CSV in a spreadsheet application and export as CSV
- Include headers matching the required format
- For batch updates, export existing episodes, modify the data, and re-import
- Use descriptive episode titles for better searchability
- If updating existing episodes, make sure the Video ID is correct and consistent
- When exporting filtered results, the CSV will only include the episodes matching your search
- The export preserves any current filtering so you can work with specific subsets of episodes