# Linking Guests to Podcast Episodes

This document explains how to link podcast guests to their episodes on the Procurement Express YouTube channel.

## Overview

Each profile can now be linked to their corresponding podcast episode with the following information:

- **Episode Number**: The sequential number of the episode
- **Episode Title**: The title of the podcast episode
- **Episode URL**: The YouTube video ID or full URL
- **Episode Date**: The date the episode was published

## Adding Episode Information

There are three ways to link a podcast guest to their episode:

### 1. Using the Admin Interface

1. Go to the Admin Portal and select "Profiles"
2. Click "Edit" for the guest you want to link
3. Scroll to the "Podcast Episode" section
4. Fill in the episode details:
   - Episode Number
   - Episode Title
   - YouTube URL or Video ID (11-character code)
   - Episode Date
5. Click "Update Profile" to save the changes

### 2. Using the Rake Task (Manual Input)

Run the following command to start an interactive process:

```
bin/rails podcast:link_episodes
```

This will prompt you for:
- Guest name (must match existing profile)
- Episode number
- Episode title
- Video ID or full YouTube URL
- Episode date (in YYYY-MM-DD format)

### 3. Using CSV Import

1. Create a CSV file with the following columns:
   - Guest Name
   - Episode Number
   - Episode Title
   - Video ID
   - Episode Date

2. Run the rake task to import the data:

```
bin/rails podcast:import_from_csv
```

3. When prompted, provide the path to your CSV file

A template CSV file is available at `lib/tasks/podcast_episodes_template.csv`.

## Filtering Profiles by Episode Status

In the admin interface, you can filter profiles by:
- All Profiles
- Podcast Guests
- With Episodes
- Missing Episodes
- Interested in Procurement

## YouTube Video IDs

A YouTube video ID is the 11-character code found in a YouTube URL. 

For example, in the URL `https://www.youtube.com/watch?v=dQw4w9WgXcQ`, the video ID is `dQw4w9WgXcQ`.

You can provide either the full URL or just the video ID. The system will handle both formats.

## Display on Public Profiles

When a guest is linked to their episode, their profile page will display:
- An embedded video player with their episode
- Episode title and number
- Episode date
- Link to watch on YouTube
- Link to the Procurement Express YouTube channel

## For Developers

### Model Structure

The `Profile` model has been extended with:
- `episode_number` (integer)
- `episode_title` (string)
- `episode_url` (string)
- `episode_date` (date)

### Rake Tasks

Available rake tasks:
- `podcast:link_episodes` - Interactive prompt to link guests to episodes
- `podcast:import_from_csv` - Import episode data from a CSV file
- `podcast:generate_template` - Generate a CSV template for importing episode data

### Helper Methods

The `Profile` model includes these helper methods:
- `formatted_episode_url` - Returns the full YouTube URL
- `episode_embed_url` - Returns the YouTube embed URL
- `has_podcast_episode?` - Returns true if the profile has any episode information