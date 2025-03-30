class RegistrationsController < ApplicationController
  def create
    @name = params[:name]
    @email = params[:email]
    @company = params[:company]
    @message = params[:message]
    @event_date = params[:event_date]
    
    # Send email to admin
    AdminMailer.event_registration_notification(@name, @email, @company, @message, @event_date).deliver_now
    
    # Redirect with success message
    redirect_to events_path, flash: { success: "Thank you for registering! We'll be in touch soon with more details." }
  rescue => e
    # Log error and redirect with error message
    Rails.logger.error("Registration email failed: #{e.message}")
    redirect_to events_path, flash: { error: "Sorry, there was a problem processing your registration. Please try again or contact us directly." }
  end
end