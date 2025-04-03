class RegistrationsController < ApplicationController
  def create
    @name = params[:name]
    @email = params[:email]
    @company = params[:company]
    @message = params[:message]
    @event_date = params[:event_date]
    
    respond_to do |format|
      # Send email to admin
      AdminMailer.event_registration_notification(@name, @email, @company, @message, @event_date).deliver_now
      
      format.html { 
        # Redirect with success message for traditional form submission
        redirect_to events_path(registration: 'success'), flash: { success: "Thank you for registering! We'll be in touch soon with more details." } 
      }
      format.json { 
        # Return JSON response for fetch API
        render json: { status: 'success', message: "Thank you for registering! We'll be in touch soon with more details." }, status: :ok 
      }
    end
  rescue => e
    # Log error
    Rails.logger.error("Registration email failed: #{e.message}")
    
    respond_to do |format|
      format.html { 
        # Redirect with error message for traditional form submission
        redirect_to events_path(registration: 'error'), flash: { error: "Sorry, there was a problem processing your registration. Please try again or contact us directly." } 
      }
      format.json { 
        # Return JSON error for fetch API
        render json: { status: 'error', message: "Sorry, there was a problem processing your registration. Please try again or contact us directly." }, status: :unprocessable_entity 
      }
    end
  end
end