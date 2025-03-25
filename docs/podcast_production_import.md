# Podcast Production Sheet Import

This document explains how to use the podcast production sheet data to maintain episodes and guest relationships in the directory.

## Overview

The system includes rake tasks to:

1. Analyze the production sheet structure
2. Import data from the production sheet
3. Link existing episodes to guest profiles

These tasks help with maintaining a synchronized database of episodes and guests.

## Analyzing the Production Sheet

Before importing, it's helpful to analyze the production sheet structure:

```bash
# Using the default file at data/production_sheet.csv
rails production:analyze

# Using a custom file path
rails production:analyze FILE=/path/to/your/sheet.csv
```

This will display:
- Total number of rows
- Column headers
- Number of filled values in each column
- Sample values for each column

Use this information to understand the data structure before importing.

## Importing Episode Data

To import data from the production sheet:

```bash
# Using the default file at data/production_sheet.csv
rails production:import

# Using a custom file path
rails production:import FILE=/path/to/your/sheet.csv
```

The import process:

1. Extracts episode numbers, titles, video IDs, and dates
2. Creates or updates episode records
3. Links episodes to guest profiles based on names
4. Updates profile headshots if available

After importing, you'll see a summary of:
- Episodes created
- Episodes updated
- Rows skipped due to missing data
- Any errors encountered

## Linking Episodes to Profiles

If you have existing episodes that aren't linked to guest profiles, you can use:

```bash
rails production:link_episodes_to_profiles
```

This process:
1. Finds episodes without linked profiles
2. Extracts guest names from episode titles
3. Matches names to profiles using fuzzy matching
4. Creates appropriate relationships

## Production Sheet Format

The importer expects a CSV file with these columns:

- Column 1: Row number (ƒcofu/cofu)
- Column 2: YouTube episode number
- Column 3: Episode name or guest name
- Column 4: Production status
- Column 5: Writing status
- Column 6: Link to guest headshot/picture
- Column 7: Job title of guest
- Column 8: Link to footage/video
- Column 9: Optional PEX comment
- Column 10: Filming date
- Column 11: Footage received date
- Column 12: Release date
- Column 13: Producer/writer name
- Columns 14-21: Various production management fields
- Column 22: Link to final video (mp4)
- Column 23: Link to mp3
- Column 24: Link to promo pack
- Column 25: Newsletter
- Column 26: Square image
- Column 27: Transcript
- Column 28: 1% Better

## Guest Name Matching

The system attempts to match guest names using several methods:

1. Exact match on name (case-insensitive)
2. Partial match on full name
3. Match on individual name parts

If a guest cannot be matched, you will see a message in the output, and you may need to manually link them.

## Video ID Extraction

The system can extract YouTube video IDs from:

1. Direct video IDs
2. Full YouTube URLs (youtube.com/watch?v=...)
3. Short YouTube URLs (youtu.be/...)

For Google Drive links, it will note that it can't extract a video ID, but will continue processing.

## Troubleshooting

If you encounter issues:

1. **Invalid dates**: The system attempts to parse various date formats, but you may need to standardize dates in your CSV.

2. **Missing video IDs**: Episodes need valid video IDs. Make sure at least column 8 (Link to Footage) or column 22 (Link to Final Video) has a valid YouTube URL.

3. **Name matching issues**: If guests aren't being matched, you can manually link them using the admin interface or by adding more guest information to the database.

4. **Duplicate episodes**: The importer checks for existing episodes by number and will update them rather than creating duplicates.

## Database Impact

This import process affects:

- `Episode` records (creating/updating)
- `ProfileEpisode` join records (creating relationships)
- `Profile` headshot URLs (updating if missing)

It does NOT modify:
- Existing episode relationships
- Profile core data
- Any other system data

## Recommended Workflow

For best results:

1. Run `rails production:analyze` to understand your data
2. Run `rails production:import` to import the data
3. Check the admin interface to verify the results
4. Run `rails production:link_episodes_to_profiles` if needed to match additional episodes
5. Manually fix any unmatched relationships through the admin interface