#!/usr/bin/env ruby
# Simple script to test email sending

require_relative 'config/environment'

# Log the mailer configuration
puts "Email delivery method: #{Rails.application.config.action_mailer.delivery_method}"
puts "Perform deliveries: #{Rails.application.config.action_mailer.perform_deliveries}"
puts "Raise delivery errors: #{Rails.application.config.action_mailer.raise_delivery_errors}"
puts "Postmark API token: #{Rails.application.config.action_mailer.postmark_settings[:api_token]}" if Rails.application.config.action_mailer.postmark_settings

# Test sending an email
begin
  test_email = "test@example.com"
  test_message = "This is a test message sent at #{Time.now}"

  # Send test email
  email = PodcastMailer.contact_confirmation(test_email, test_message)
  result = email.deliver_now

  puts "Email sent successfully!"
  puts "Email details:"
  puts "  From: #{email.from}"
  puts "  To: #{email.to}"
  puts "  Subject: #{email.subject}"
  puts "  Message ID: #{email.message_id}"
  puts "  Delivery result: #{result.inspect}"
rescue => e
  puts "Error sending email: #{e.message}"
  puts e.backtrace.join("\n")
end
