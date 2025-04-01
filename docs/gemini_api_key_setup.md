# Setting up Gemini API for YouTube Summarization

This document explains how to set up and configure the Google Gemini API for the YouTube summarization feature.

## Creating a Gemini API Key

1. Go to the Google AI Studio: https://makersuite.google.com/app/apikey
2. Sign in with your Google account
3. Click on "Get API key" or "Create API key" button
4. Name your API key (e.g., "Podcast Summarization")
5. Copy the API key that starts with "AIza..."

## Setting the API Key on Fly.io

```bash
# Set the API key as a secret on Fly.io
fly secrets set GOOGLE_API_KEY=AIza...your-actual-key...

# Verify the key was set correctly
fly secrets get GOOGLE_API_KEY
# The output should be your API key, starting with "AIza"
```

## Troubleshooting the Invalid API Key Issue

The current GOOGLE_API_KEY set in Fly.io is invalid - it appears to be 841 characters long, which is not a valid Gemini API key format. A valid Gemini API key:

1. Starts with `AIza`
2. Is approximately 39 characters in total
3. Contains only alphanumeric characters, hyphens, and underscores

To fix this issue:

1. Create a new API key following the steps above
2. Delete the existing invalid key: `fly secrets unset GOOGLE_API_KEY`
3. Set the new valid key: `fly secrets set GOOGLE_API_KEY=AIza...your-new-key...`
4. Restart the application: `fly app restart`

## Verifying the API Key Works

You can test that your API key works by running:

```ruby
ruby test_gemini_api.rb
```

If everything is working correctly, you should see a successful API response.

## Related Documentation

- [Google AI documentation](https://ai.google.dev/)
- [Gemini API documentation](https://ai.google.dev/docs/gemini_api_overview)