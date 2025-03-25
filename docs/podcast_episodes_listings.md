# Podcast Episodes Listing Feature

This document explains the new podcast episodes listing functionality added to the application.

## Overview

The podcast episodes listing feature allows users to:

1. View a grid of all podcast episodes
2. Filter episodes by title, episode number, or year
3. See episode details including the primary guest and number of co-hosts
4. View detailed episode pages with embedded video players
5. Navigate between episodes

## Key Components

### Episodes Index Page

This page shows a grid of all podcast episodes with:

- Episode thumbnails with play button overlays
- Episode number and air date
- Episode title
- Primary guest information with photo
- Number of additional guests
- Links to watch on YouTube or view episode details

The page includes filtering options:
- Search by title or episode number
- Filter by year
- Clear filters button

### Episode Show Page

This page displays detailed information about a specific episode:

- Embedded YouTube video player
- Episode title, number, and air date
- Episode notes (if available)
- Primary guest information with:
  - Photo
  - Name and company
  - Segment information (if applicable)
  - Social links
  - Link to guest profile
- Co-host/additional guest information with:
  - Photos
  - Names and companies
  - Appearance types
  - Segment information (if applicable)
- Previous/Next episode navigation
- Back to episodes list link

## Model Structure

The episodes feature is built on the following models:

1. **Episode**: Represents a podcast episode
   - number: Unique episode number
   - title: Episode title
   - video_id: YouTube video ID
   - air_date: Publication date
   - notes: Episode description or show notes
   - thumbnail_url: Custom thumbnail (falls back to YouTube thumbnail)
   - duration_seconds: Episode length in seconds

2. **ProfileEpisode**: Join model connecting profiles (guests) to episodes
   - profile_id: Reference to the guest profile
   - episode_id: Reference to the episode
   - appearance_type: Role in the episode (Main Guest, Co-Host, etc.)
   - is_primary_guest: Boolean flag for the main guest
   - segment_title: Title of the specific segment (optional)
   - segment_start_time: Timestamp for when the guest appears (in seconds)
   - segment_end_time: Timestamp for when the guest's segment ends (in seconds)
   - notes: Additional notes about the appearance

## Technical Implementation

### Responsive Design

- The episodes index uses a responsive grid:
  - 1 column on mobile
  - 2 columns on medium screens
  - 3 columns on large screens
- Video player uses aspect ratio preservation for consistent display
- Guest information adapts to available space

### YouTube Integration

- Automatic thumbnail generation from video IDs
- Embedded player support
- Direct links to specific timestamps for guest segments
- Watch on YouTube links for each episode

### Performance Considerations

- Eager loading of associations to minimize database queries
- Caching thumbnail URLs to reduce API calls
- Index on episode number and video_id for fast lookups

## Data Management

Episodes can be managed through:

1. Admin interface (coming soon)
2. Rake tasks:
   - `podcast:create_episode`: Interactive creation of episodes with multiple guests
   - `podcast:import_episodes_from_csv`: Bulk import from CSV files
   - `podcast:generate_episodes_template`: Generate CSV template for importing
   - `podcast:create_sample_episodes`: Create test episodes for development

## User Flow

1. User clicks "Episodes" in the main navigation
2. Episodes index displays all podcast episodes
3. User can:
   - Browse through episodes
   - Filter episodes by title, number, or year
   - Click an episode to view details
4. On the episode page, users can:
   - Watch the embedded video
   - Learn about the guests
   - Jump to specific segments
   - Navigate to guest profiles
   - Move to previous/next episodes

## Future Enhancements

Planned enhancements include:

1. Admin interface for managing episodes
2. Podcast RSS feed generation
3. Transcripts and show notes
4. Related episodes suggestions
5. Comments and social sharing
6. Analytics integration to track views and engagement