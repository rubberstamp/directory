# Podcast Episode Summarization with Gemini AI

This document provides detailed information on setting up and troubleshooting the episode summarization feature.

## Overview

The episode summarization feature automatically generates professional summaries for podcast episodes based on their titles and descriptions. It uses Google's Gemini AI to create well-written, concise summaries that highlight the key topics discussed in each episode.

**Note**: While the feature is labeled as "YouTube summarization" in the UI, Gemini AI cannot actually access or watch YouTube videos directly. Instead, it generates summaries based on the episode's title, number, and description/notes. The YouTube video ID is included as reference only.

## Setup Requirements

1. Google Account (Gmail)
2. Gemini API Key
3. Configuration in Rails credentials

## Detailed Setup Steps

### 1. Get a Gemini API Key

1. Go to [Google AI Studio](https://makersuite.google.com/app/apikey)
2. Sign in with your Google account 
3. Click "Create API Key"
4. Copy the API key to a secure location

### 2. Configure Rails application

Edit your Rails credentials:
```bash
EDITOR="code --wait" rails credentials:edit
```

Add your Gemini API key:
```yaml
google_cloud:
  project_id: any-identifier-you-want  # This can be any string
  api_key: your-gemini-api-key-here    # The API key you created in step 1
```

### 3. Restart your Rails server

After setting up credentials, restart your Rails server:
```bash
bin/dev
```

## Troubleshooting

### Common Errors

#### "Google Cloud API key is not configured in Rails credentials"

**Solution**: Add your Gemini API key to Rails credentials as shown in the setup steps.

#### "Gemini API error: 400 - API key not valid"

**Solutions**:
1. Check that your API key is correctly copied to Rails credentials
2. Create a new API key if the current one is not working
3. Check if you've exceeded your quota limits

#### "Unknown field name 'prompt' in initialization map entry"

**Solution**: This is a format error. The service has been updated to use the correct format.

### Testing the Service

You can test the service is working by running:

```ruby
# From Rails console
episode = Episode.find_by(video_id: "YOUTUBE_VIDEO_ID")  # Replace with actual video ID
service = YoutubeSummarizerService.new(episode)
summary = service.call  # Should return summary if everything is configured correctly
```

## Usage

### Generating Summaries

1. Navigate to the Episode details page in the admin panel
2. If the episode has a valid YouTube video ID, you'll see a "Generate Summary" button
3. Click the button to queue a background job that will generate the summary
4. The summary will appear on both the admin and public episode pages once generated

### Managing Summaries

- **View summaries**: Summaries appear in the episode detail page in both admin and public views
- **Edit summaries**: You can manually edit summaries in the episode edit form
- **Regenerate summaries**: If a summary already exists, you can click "Regenerate Summary" to create a new one

### Video ID Requirements

For the summary generation to work properly, episodes must have:
1. A valid YouTube video ID (11 characters) or a valid YouTube URL
2. Videos must be publicly accessible (not private or unlisted)
3. If using a full URL, it must be a standard YouTube watch URL (e.g., https://www.youtube.com/watch?v=xxxx)

## Notes

- The Gemini model used is `gemini-1.5-flash` which is optimized for efficiency
- For better quality summaries, you can change the model to `gemini-1.5-pro` in the service code
- Free API keys have usage quotas and rate limits
- Paid API keys are available for higher usage through Google Cloud
- The service handles videos that are not found or have errors gracefully
- Summaries can be manually written or edited if the AI-generated ones are not satisfactory