namespace :db do
  # Prepare specific database configs
  namespace :prepare do
    desc "Prepare the queue database"
    task queue: :environment do
      ActiveRecord::Base.establish_connection(:queue)

      # Create queue_schema table if it doesn't exist
      unless ActiveRecord::Base.connection.table_exists?("queue_schema")
        ActiveRecord::Base.connection.create_table("queue_schema") do |t|
          t.string :version, null: false
        end
      end

      # Check if we have the SolidQueue tables
      unless ActiveRecord::Base.connection.table_exists?("solid_queue_jobs")
        # Load SolidQueue schema
        load File.expand_path("../../db/queue_schema.rb", __dir__)
        puts "Queue database schema loaded."
      else
        puts "Queue database schema already exists."
      end
    end

    desc "Prepare the cache database"
    task cache: :environment do
      ActiveRecord::Base.establish_connection(:cache)

      # Create cache_schema table if it doesn't exist
      unless ActiveRecord::Base.connection.table_exists?("cache_schema")
        ActiveRecord::Base.connection.create_table("cache_schema") do |t|
          t.string :version, null: false
        end
      end

      # Check if we have the ActiveSupport::Cache tables
      unless ActiveRecord::Base.connection.table_exists?("active_storage_blobs")
        # Load Cache schema
        load File.expand_path("../../db/cache_schema.rb", __dir__)
        puts "Cache database schema loaded."
      else
        puts "Cache database schema already exists."
      end
    end

    desc "Prepare the cable database"
    task cable: :environment do
      ActiveRecord::Base.establish_connection(:cable)

      # Create cable_schema table if it doesn't exist
      unless ActiveRecord::Base.connection.table_exists?("cable_schema")
        ActiveRecord::Base.connection.create_table("cable_schema") do |t|
          t.string :version, null: false
        end
      end

      # Check if we have the ActionCable tables
      unless ActiveRecord::Base.connection.table_exists?("cable_subscriptions")
        # Load Cable schema
        load File.expand_path("../../db/cable_schema.rb", __dir__)
        puts "Cable database schema loaded."
      else
        puts "Cable database schema already exists."
      end
    end
  end

  # Add these tasks as dependencies to the main db:prepare task
  Rake::Task["db:prepare"].enhance do
    Rake::Task["db:prepare:queue"].invoke
    Rake::Task["db:prepare:cache"].invoke
    Rake::Task["db:prepare:cable"].invoke
  end
end

namespace :fly do
  desc "Tasks needed before deploying to Fly.io"
  task release: "db:prepare"

  desc "Ensure database permissions are set correctly"
  task fix_permissions: :environment do
    puts "Checking database permissions..."

    # Get the list of database files
    db_files = [
      ENV.fetch("SQLITE_DATABASE", "storage/production.sqlite3"),
      ENV.fetch("SQLITE_CACHE_DATABASE", "storage/production_cache.sqlite3"),
      ENV.fetch("SQLITE_QUEUE_DATABASE", "storage/production_queue.sqlite3"),
      ENV.fetch("SQLITE_CABLE_DATABASE", "storage/production_cable.sqlite3")
    ]

    # Check each file
    db_files.each do |file|
      if File.exist?(file)
        # Ensure file is writable
        unless File.writable?(file)
          puts "Fixing permissions for #{file}..."
          system("chmod", "666", file)
        end
      else
        puts "Database file #{file} does not exist yet."
      end
    end

    puts "Database permissions check complete."
  end
end
