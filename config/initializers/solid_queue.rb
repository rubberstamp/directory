# Ensure SolidQueue is properly initialized in all environments
Rails.application.config.after_initialize do
  # Only run queue initialization in worker processes or if explicitly configured to run in web process
  run_in_web = ENV["SOLID_QUEUE_IN_PUMA"] == "true"
  is_worker = $PROGRAM_NAME.include?("bin/jobs") || $PROGRAM_NAME.include?("solid_queue:start")

  if is_worker || run_in_web
    # Create marker file to verify process is running
    File.write("/tmp/solid_queue_worker_running", Time.now.to_s) if Rails.env.production?

    # Set database connection
    begin
      if defined?(SolidQueue)
        # Create touch file for monitoring
        Rails.logger.info("SolidQueue initialized. Using database: #{ActiveRecord::Base.connection_db_config.configuration_hash[:database]}")

        # Connect to dedicated queue database in production
        if Rails.configuration.respond_to?(:solid_queue) &&
           Rails.configuration.solid_queue.respond_to?(:connects_to) &&
           Rails.env.production?
          Rails.logger.info("Connecting SolidQueue to dedicated queue database")
          ActiveRecord::Base.establish_connection(:queue)
        end
      else
        Rails.logger.warn("SolidQueue not available. Background jobs will not process.")
      end
    rescue => e
      Rails.logger.error("Error initializing SolidQueue: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
    end
  else
    Rails.logger.info("SolidQueue initialization skipped - not running in worker process")
  end
end
