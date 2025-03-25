# Supporting Multiple Guests on Podcast Episodes

This document explains how to manage podcast episodes with multiple guests.

## Overview

The application now supports podcast episodes with multiple guests, which allows for:

- Multiple guests appearing on the same episode
- Different types of appearances (main guest, co-host, panel member, etc.)
- Tracking specific segments within an episode
- Identifying primary vs. secondary guests for each episode

## Data Model

The updated data model includes:

### Episodes

Each episode represents one podcast recording with the following information:
- Episode number (unique)
- Title
- Video ID (YouTube)
- Air date
- Thumbnail URL (optional)
- Duration in seconds (optional)
- Notes (optional)

### Profile Episodes (Join Table)

This join table connects profiles to episodes with additional details:
- Profile (guest)
- Episode 
- Appearance type (Main Guest, Co-Host, Panel Member, etc.)
- Primary guest flag (true/false)
- Segment title (optional)
- Segment start time (in seconds, optional)
- Segment end time (in seconds, optional)
- Notes about the appearance (optional)

## Managing Episodes

### Creating Episodes

You can create episodes in several ways:

1. **Admin Interface** (coming soon)
   - Navigate to the Episodes section
   - Click "New Episode"
   - Fill in the details and add guests

2. **Rake Task (Interactive)**
   ```
   bin/rails podcast:create_episode
   ```
   This will guide you through creating an episode and adding multiple guests.

3. **Bulk Import via CSV**
   - First, generate a template:
     ```
     bin/rails podcast:generate_episodes_template
     ```
   - Fill in the template with your episode data
   - Import the data:
     ```
     bin/rails podcast:import_episodes_from_csv
     ```

### Example CSV Format

The CSV format for importing episodes supports multiple guests per episode:

```csv
Episode Number,Episode Title,Video ID,Episode Date,Guest Name,Appearance Type,Is Primary Guest,Segment Title,Segment Start Time,Segment End Time,Notes
42,How to Optimize Procurement,abcd1234xyz,2025-01-15,John Doe,Main Guest,yes,,,,"Main interview"
42,How to Optimize Procurement,abcd1234xyz,2025-01-15,Jane Smith,Co-Host,no,Finance segment,1800,2400,"Second half of the show"
43,Procurement Panel Discussion,efgh5678abc,2025-01-22,Alice Johnson,Panel Member,yes,,,,Moderated the panel
43,Procurement Panel Discussion,efgh5678abc,2025-01-22,Bob Williams,Panel Member,no,,,,
43,Procurement Panel Discussion,efgh5678abc,2025-01-22,Carol Davis,Panel Member,no,,,,
```

In this format:
- Rows with the same Episode Number belong to the same episode
- Each guest gets their own row
- Only one guest should be marked as primary (Is Primary Guest = yes)
- Segment times are optional and specified in seconds

## Appearance Types

The system supports these appearance types:
- Main Guest
- Co-Host
- Panel Member
- Special Guest
- Expert Commentary
- Interview Subject

## Segments

For episodes with multiple segments or guests appearing at specific times, you can specify:
- Segment title (e.g., "Finance Discussion", "Q&A Section")
- Start time in seconds (e.g., 1800 for 30 minutes in)
- End time in seconds (optional)

This allows linking directly to specific parts of an episode where a guest appears.

## Displaying Episodes on Profiles

Each profile page will now display:
- All episodes the guest has appeared on
- Their role in each episode (Main Guest, Co-Host, etc.)
- Direct links to their segments (if specified)

The most recent episode or primary guest episodes will be featured more prominently.

## Migrating from Single-Guest Model

If you previously used the single-guest model, you can migrate the data:

```
bin/rails podcast:migrate_episode_data
```

This will:
1. Create new Episode records from the old profile data
2. Link profiles to episodes with appropriate associations
3. Preserve all existing information

## For Developers

The following models are available:

- `Episode`: Represents a podcast episode
- `ProfileEpisode`: Join model linking profiles to episodes

Key methods:

On `Profile`:
- `episodes_by_date`: All episodes ordered by date
- `primary_guest_episodes`: Episodes where profile is primary guest
- `secondary_appearances`: Non-primary appearances
- `latest_episode`: Most recent episode

On `Episode`:
- `primary_guest`: Returns the primary guest for the episode
- `youtube_url`: Generates a full YouTube URL for the episode
- `embed_url`: Generates the embed URL for the video player

On `ProfileEpisode`:
- `segment_youtube_url`: URL with timestamp for the segment
- `segment_start_formatted`: Formats start time as MM:SS
- `segment_end_formatted`: Formats end time as MM:SS