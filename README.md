# Directory

A web application for managing profiles, podcast episodes, and a directory of professionals.

## System Requirements

* Ruby 3.2.0 or higher
* Node.js 16+ (for Tailwind CSS)
* PostgreSQL (for production)
* SQLite (for development)
* ImageMagick (for image processing)

## Development Setup

1. Clone the repository
```bash
git clone https://github.com/rubberstamp/directory.git
cd directory
```

2. Install dependencies
```bash
bundle install
```

3. Setup the database
```bash
bin/rails db:setup
```

4. Start the development server
```bash
bin/dev
```

5. Visit http://localhost:3000

## Deployment

### Configuration

This application is configured to run on ephemeral storage platforms like Fly.io or Heroku. It uses:

* PostgreSQL for the database in production
* Amazon S3 for file storage with ActiveStorage
* SolidCache/SolidQueue for background jobs and caching

### Environment Variables

Set these environment variables for production:

```
# Database
DATABASE_URL=postgres://username:password@hostname:port/database_name

# AWS S3 for ActiveStorage
AWS_ACCESS_KEY_ID=your_access_key
AWS_SECRET_ACCESS_KEY=your_secret_key
AWS_REGION=your_region
AWS_BUCKET=your_bucket_name

# Rails
RAILS_MASTER_KEY=your_master_key
RAILS_ENV=production
```

### Deploying to Fly.io with SQLite

We've configured this app to use SQLite with a persistent volume on Fly.io, which is simple and cost-effective.

1. Install the Fly CLI
```bash
curl -L https://fly.io/install.sh | sh
```

2. Login to Fly
```bash
fly auth login
```

3. Create a Fly.io app (first time only)
```bash
fly launch --name your-app-name --no-deploy
```

4. Create a persistent volume for SQLite (first time only)
```bash
fly volumes create sqlite_data --size 1 --region iad
```

5. Set required secrets
```bash
fly secrets set RAILS_MASTER_KEY=$(cat config/master.key)
```

6. Set AWS S3 secrets (for ActiveStorage)
```bash
fly secrets set AWS_ACCESS_KEY_ID=your_key AWS_SECRET_ACCESS_KEY=your_secret AWS_REGION=your_region AWS_BUCKET=your_bucket
```

7. Deploy using our convenience script
```bash
bin/fly-deploy
```

For more detailed instructions, see [Deploying on Fly with SQLite](docs/deploying_on_fly_with_sqlite.md).

### Deploying to Heroku

1. Install the Heroku CLI
```bash
curl https://cli-assets.heroku.com/install.sh | sh
```

2. Login to Heroku
```bash
heroku login
```

3. Create a new Heroku app
```bash
heroku create
```

4. Set buildpacks
```bash
heroku buildpacks:add heroku/ruby
```

5. Set environment variables
```bash
heroku config:set AWS_ACCESS_KEY_ID=your_key AWS_SECRET_ACCESS_KEY=your_secret AWS_REGION=your_region AWS_BUCKET=your_bucket RAILS_MASTER_KEY=your_key
```

6. Add PostgreSQL
```bash
heroku addons:create heroku-postgresql
```

7. Deploy
```bash
git push heroku main
```

## Features

* Profile management
* Podcast episode tracking
* Specialization management
* Admin dashboard
* Map view of profiles
* Headshot management with ActiveStorage
* YouTube video summarization with Gemini AI

## YouTube Video Summarization Setup

This application uses Google Cloud's Vertex AI with Gemini models to automatically generate summaries for podcast episodes from their YouTube videos. To set up:

### 1. Get a Gemini API Key

1. Go to [Google MakerSuite](https://makersuite.google.com/app/apikey)
2. Create a new API key

### 2. Add your API key to Rails credentials

```bash
EDITOR="code --wait" rails credentials:edit
```

Add the following to your credentials file:
```yaml
google_cloud:
  project_id: your-project-id
  api_key: your-gemini-api-key
```

### 5. Restart your Rails server

After configuring everything, restart your Rails server to apply the changes:
```bash
bin/dev
```

## License

This project is available as open source under the terms of the MIT License.