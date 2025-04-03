# AI Bio Generation System

This document describes the AI-powered bio generation system implemented for podcast guests.

## Overview

The system automatically generates professional bios for podcast guests based on their podcast episodes, specializations, and other profile information. It uses Google's Gemini API to generate contextually relevant bios that highlight the guest's expertise, background, and insights from their podcast appearances.

**Important:** The system only generates bios for profiles that don't already have one. It will never overwrite an existing bio.

## Features

- Automatically generates professional bios for podcast guests
- Uses podcast episode data, summaries, and guest profile information
- Handles both primary guests and secondary appearances
- Only generates bios for profiles that don't already have one
- Runs asynchronously via background jobs to avoid blocking the application
- Provides both individual and batch processing capabilities

## Components

### 1. GuestBioGeneratorService

The core service that interacts with the Gemini AI model to generate bios.

- Located at: `app/services/guest_bio_generator_service.rb`
- Requires Google Cloud API key for authentication
- Uses the same configuration as the YouTube summarizer service
- Extracts relevant information from the guest's profile and episodes
- Builds a comprehensive prompt that encourages the AI to create a professional bio
- Handles errors gracefully and provides detailed logging

### 2. GenerateGuestBioJob

A background job that processes bio generation asynchronously.

- Located at: `app/jobs/generate_guest_bio_job.rb`
- Takes a profile ID as input
- Calls the GuestBioGeneratorService to generate the bio
- Updates the profile with the generated bio
- Handles errors without affecting the application flow

### 3. Profile Model Extensions

Extensions to the Profile model to support bio generation.

- Added methods: `generate_ai_bio` and `generate_ai_bio_later`
- These methods check if the profile has episodes and queue the bio generation job

### 4. Admin Interface

Admin interface extensions for managing bio generation.

- Individual bio generation: Button on profile show page
- Batch bio generation: Button on profiles index page
- Controller actions: `generate_bio` and `generate_all_bios`

## Usage

### Individual Bio Generation

Admins can generate a bio for a specific guest by:

1. Navigating to the profile show page in the admin area
2. Clicking the "Generate AI Bio" button in the Bio section
3. The bio will be generated asynchronously and the page will be updated

### Batch Bio Generation

To generate bios for multiple profiles:

1. Go to the profiles index page in the admin area
2. Click the "Generate Missing Bios" button
3. Confirm the action when prompted

The system will identify all profiles that have episodes but no bio, and queue background jobs to generate bios for them.

## Technical Details

### Dependencies

- Requires a Google Cloud API key configured in the application credentials or environment variables
- Uses the Gemini API (same as the YouTube summarizer)
- Requires podcast episode data for the guests

### Configuration

Configuration is shared with the YouTube summarizer service:

```ruby
PROJECT_ID = ENV["GOOGLE_CLOUD_PROJECT_ID"] || Rails.application.credentials.dig(:google_cloud, :project_id)
LOCATION = ENV["GOOGLE_CLOUD_LOCATION"] || Rails.application.credentials.dig(:google_cloud, :location) || "us-central1"
API_KEY = ENV["GOOGLE_API_KEY"] || Rails.application.credentials.dig(:google_cloud, :api_key)
MODEL_NAME = ENV["GEMINI_MODEL_NAME"] || "gemini-1.5-flash"
```

### Testing

Tests are available for both the service and job:

- Service tests: `test/services/guest_bio_generator_service_test.rb`
- Job tests: `test/jobs/generate_guest_bio_job_test.rb`

## Future Improvements

Potential future enhancements:

1. Add option to regenerate bios for profiles that already have them
2. Implement a way to track when bios were last generated
3. Add a way to compare AI-generated bios with existing ones
4. Provide more control over the generation parameters
5. Add a preview function to review a generated bio before applying it