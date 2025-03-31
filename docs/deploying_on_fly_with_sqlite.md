# Deploying on Fly.io with SQLite

This guide provides instructions for deploying this Rails application on Fly.io using SQLite as the database with a persistent volume and AWS S3 for file storage.

## Deployment Architecture

The application uses multiple SQLite databases:

1. **Primary database** - Main application data (profiles, episodes, etc.)
2. **Queue database** - For SolidQueue background job processing
3. **Cache database** - For ActiveSupport::Cache
4. **Cable database** - For ActionCable (WebSocket) functionality

All databases are stored in a persistent volume mounted at `/data`.

## Prerequisites

- Fly.io account
- AWS S3 bucket for file storage
- AWS credentials with appropriate permissions

## Deployment Steps

1. Install Fly.io CLI:
   ```bash
   curl -L https://fly.io/install.sh | sh
   ```

2. Login to Fly.io:
   ```bash
   fly auth login
   ```

3. Create the application:
   ```bash
   fly apps create directory
   ```

4. Create a persistent volume for SQLite:
   ```bash
   fly volumes create sqlite_data --size 1 --region iad
   ```

5. Set up AWS S3 credentials as secrets:
   ```bash
   fly secrets set AWS_ACCESS_KEY_ID=your_access_key AWS_SECRET_ACCESS_KEY=your_secret_key AWS_REGION=your_region AWS_BUCKET=your_bucket_name
   ```

6. Set the Rails master key:
   ```bash
   fly secrets set RAILS_MASTER_KEY=your_master_key
   ```

7. Deploy the application using our custom deploy script:
   ```bash
   bin/fly-deploy
   ```
   
   This script:
   - Deploys the app
   - Runs migrations on the primary database
   - Runs migrations on all secondary databases (queue, cache, cable)

## Configuration Files

### fly.toml

```toml
app = "directory"
primary_region = "iad"
console_command = "/rails/bin/rails console"

[build]
  [build.args]
    BUNDLER_VERSION = "2.3.7"
    NODE_VERSION = "16.15.1"
    RUBY_VERSION = "3.2.0"

[deploy]
  release_command = "bin/rails fly:release"

[env]
  PORT = "3000"
  SERVER_COMMAND = "bin/rails server"

[http_service]
  internal_port = 3000  # Important: Must match the port in the Dockerfile and Puma config
  force_https = true
  auto_stop_machines = false
  auto_start_machines = true
  min_machines_running = 1
  processes = ["app"]

[processes]
  app = "bin/rails server -p 3000"
  worker = "bin/jobs"

[[statics]]
  guest_path = "/rails/public"
  url_prefix = "/"

[mounts]
  source = "sqlite_data"
  destination = "/data"
```

### config/database.yml

```yaml
production:
  primary:
    <<: *default
    database: <%= ENV.fetch("SQLITE_DATABASE", "/data/production.sqlite3") %>
  cache:
    <<: *default
    database: <%= ENV.fetch("SQLITE_CACHE_DATABASE", "/data/production_cache.sqlite3") %>
    migrations_paths: db/cache_migrate
  queue:
    <<: *default
    database: <%= ENV.fetch("SQLITE_QUEUE_DATABASE", "/data/production_queue.sqlite3") %>
    migrations_paths: db/queue_migrate
  cable:
    <<: *default
    database: <%= ENV.fetch("SQLITE_CABLE_DATABASE", "/data/production_cable.sqlite3") %>
    migrations_paths: db/cable_migrate
```

## File Storage

This application uses ActiveStorage with AWS S3 for file storage in production. The configuration is in `config/storage.yml`:

```yaml
amazon:
  service: S3
  access_key_id: <%= ENV['AWS_ACCESS_KEY_ID'] || Rails.application.credentials.dig(:aws, :access_key_id) %>
  secret_access_key: <%= ENV['AWS_SECRET_ACCESS_KEY'] || Rails.application.credentials.dig(:aws, :secret_access_key) %>
  region: <%= ENV['AWS_REGION'] || Rails.application.credentials.dig(:aws, :region) || 'us-east-1' %>
  bucket: <%= ENV['AWS_BUCKET'] || Rails.application.credentials.dig(:aws, :bucket) %>
  force_path_style: true
```

## File Upload

The application handles file uploads through ActiveStorage. The main features are:

1. Profile headshots through the admin interface
2. Compatible with both ActiveStorage and legacy URL storage

## Maintenance

### Database Backup

To backup the SQLite database from the persistent volume:

```bash
fly ssh sftp get /data/production.sqlite3 ./backup_production.sqlite3
```

### Migrating Database

To run migrations on the deployed application:

```bash
fly ssh console -C "/bin/bash -c 'cd /rails && bin/rails db:migrate'"
```

### Troubleshooting

#### Database Migration Issues

If the database migration doesn't run automatically during deployment:

1. Check the volume permissions:
   ```bash
   fly ssh console -C "ls -la /data"
   ```

2. Manually fix permissions if needed:
   ```bash
   fly ssh console -C "sudo chown -R rails:rails /data"
   ```

3. Run migrations manually:
   ```bash
   fly ssh console -C "/bin/bash -c 'cd /rails && bin/rails db:migrate'"
   ```

#### Background Worker Issues

If the worker process fails with errors about SolidQueue tables:

1. Manually run the queue database preparation:
   ```bash
   fly ssh console -C "cd /rails && bin/rails db:prepare:queue"
   ```

2. Restart the worker process:
   ```bash
   fly machine restart --process worker
   ```

If there are permission issues with the databases:

1. Fix permissions with our rake task:
   ```bash
   fly ssh console -C "cd /rails && bin/rails fly:fix_permissions"
   ```

2. Restart the worker process:
   ```bash
   fly machine restart --process worker
   ```

### Port Configuration Issues

If the application is not accessible, check that all port configurations match:

1. Ensure these files all use the same port (3000):
   - `fly.toml`: Should have `PORT = "3000"` in [env] and `internal_port = 3000` in [http_service]
   - `Dockerfile`: Should have `EXPOSE 3000` and `CMD ["./bin/thrust", "./bin/rails", "server", "-p", "3000"]`
   - `config/puma.rb`: Should have `port ENV.fetch("PORT", 3000)`

2. To fix port mismatches:
   ```bash
   # Update and redeploy
   fly deploy
   ```

3. Check logs for binding issues:
   ```bash
   fly logs
   ```