namespace :deployment do
  desc "Tasks to run during deployment"
  task prepare: :environment do
    # Ensure data directory exists with correct permissions
    data_dir = "/data"
    if Dir.exist?(data_dir)
      # Make data directory writable by rails user
      system("sudo chown -R rails:rails #{data_dir}")
      puts "Set permissions on #{data_dir}"
    else
      puts "Data directory #{data_dir} not found or not mounted"
    end

    # Execute database setup and migrations
    begin
      puts "Creating database if it doesn't exist..."
      Rake::Task["db:create"].invoke
      puts "Running migrations..."
      Rake::Task["db:migrate"].invoke
      puts "Running schema load if needed..."
      Rake::Task["db:schema:load"].invoke if ActiveRecord::Base.connection.tables.empty?
      puts "Database setup completed!"
    rescue => e
      puts "Database setup error: #{e.message}"
      puts e.backtrace.join("\n")
    end
    
    # Migrate headshots to ActiveStorage
    Rake::Task["headshots:migrate_to_active_storage"].invoke if defined?(ActiveStorage) && Rake::Task.task_defined?("headshots:migrate_to_active_storage")
    
    # Other deployment tasks
    puts "Running deployment preparation tasks..."
    
    # Ensure all ActiveStorage blobs are migrated to S3
    if defined?(ActiveStorage) && Rails.application.config.active_storage.service == :amazon
      puts "Ensuring ActiveStorage blobs are migrated to S3..."
      ActiveStorage::Blob.find_each do |blob|
        begin
          if blob.service.respond_to?(:mirror_later)
            blob.service.mirror_later(blob.key)
            print "."
          end
        rescue => e
          puts "Error with blob #{blob.id}: #{e.message}"
        end
      end
      puts " Done!"
    end
  end
end

# Add a task for Heroku or Fly.io release phase
namespace :fly do
  task :release => "deployment:prepare"
end

namespace :heroku do
  task :release => "deployment:prepare"
end