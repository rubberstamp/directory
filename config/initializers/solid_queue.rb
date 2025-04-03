# Ensure SolidQueue is properly initialized in all environments
Rails.application.config.after_initialize do
  # Create marker file to verify process is running
  File.write('/tmp/solid_queue_worker_running', Time.now.to_s) if Rails.env.production?
  
  # Set database connection
  begin
    if defined?(SolidQueue)
      # Create touch file for monitoring
      Rails.logger.info("SolidQueue initialized. Using database: #{ActiveRecord::Base.connection_db_config.configuration_hash[:database]}")
      
      # Force connection to queue database if configured 
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
end