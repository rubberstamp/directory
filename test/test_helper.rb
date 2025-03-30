ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    # Disable parallelism to avoid concurrent test issues
    parallelize(workers: 1)

    # Instead of loading all fixtures, we'll specify which ones each test needs
    # fixtures :all

    # Add more helper methods to be used by all tests here...
    
    # Clear database before tests
    setup do
      User.destroy_all
      Profile.destroy_all
      Specialization.destroy_all
      Episode.destroy_all
      ProfileSpecialization.destroy_all
      ProfileEpisode.destroy_all
    end
    
    # Set default mailer config for tests if not set
    Rails.application.config.action_mailer.default_url_options ||= { host: 'localhost', port: 3000 }
    Rails.application.config.podcast_admin_email ||= "admin-test@example.com" # Default admin email for tests
    Rails.application.config.podcast_email ||= "podcast-test@example.com" # Default from email for tests
    
    # Ensure mailer settings for tests
    ActionMailer::Base.delivery_method = :test
    ActionMailer::Base.perform_deliveries = true
    ActionMailer::Base.deliveries.clear
  end
end

class ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  include ActiveJob::TestHelper # Include ActiveJob test helpers

  def sign_in_as_admin
    @admin = User.create!(
      email: "admin-#{rand(1000)}@example.com", 
      password: 'password123', 
      password_confirmation: 'password123',
      admin: true
    )
    post '/users/sign_in', params: { 
      user: { email: @admin.email, password: 'password123' } 
    }
  end

  def sign_in_as_user
    @user = User.create!(
      email: "user-#{rand(1000)}@example.com", 
      password: 'password123',
      password_confirmation: 'password123',
      admin: false
    )
    post '/users/sign_in', params: { 
      user: { email: @user.email, password: 'password123' } 
    }
  end
  
  # Access controller instance variables in integration tests
  def assigns(variable_name)
    @controller.instance_variable_get("@#{variable_name}")
  end
end
