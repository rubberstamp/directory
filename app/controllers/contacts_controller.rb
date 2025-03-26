class ContactsController < ApplicationController
  def index
    # Initialize empty form variables
    @name = ""
    @email = ""
    @phone = ""
    @message = ""
  end
  
  def create
    @name = params[:name]
    @email = params[:email]
    @phone = params[:phone]
    @message = params[:message]
    
    # Basic validation
    if @email.blank? || @message.blank?
      flash[:error] = "Please provide your email and message"
      redirect_to contact_path
      return
    end
    
    # Skip the email sending for now and just show success
    flash[:success] = "Thank you for your message! We'll get back to you soon."
    redirect_to contact_path
    
    # Instead of sending real emails, log the information for now
    Rails.logger.info "CONTACT FORM SUBMISSION: Name: #{@name}, Email: #{@email}, Phone: #{@phone}"
    Rails.logger.info "Message: #{@message}"
    
    # This is the original email sending code that we'll enable later
    # begin
    #   PodcastMailer.contact_confirmation(@email, @message).deliver_now
    #   
    #   # Notify the admin
    #   admin_email = Rails.application.config.podcast_admin_email
    #   AdminMailer.new_contact_notification(admin_email, @name, @email, @phone, @message).deliver_now if defined?(AdminMailer)
    #   
    #   flash[:success] = "Thank you for your message! We'll get back to you soon."
    # rescue => e
    #   Rails.logger.error "Error sending contact email: #{e.message}"
    #   flash[:error] = "There was a problem sending your message. Please try again later."
    # end
  end
  
  def subscribe
    @email = params[:email]
    @name = params[:name]
    
    # Basic validation
    if @email.blank?
      flash[:error] = "Please provide your email to subscribe"
      redirect_to root_path
      return
    end
    
    # Skip the email sending for now and just show success
    flash[:success] = "Thank you for subscribing to our podcast newsletter!"
    redirect_to root_path
    
    # Instead of sending real emails, log the information for now
    Rails.logger.info "NEWSLETTER SUBSCRIPTION: Email: #{@email}, Name: #{@name}"
    
    # This is the original email sending code that we'll enable later
    # begin
    #   PodcastMailer.welcome_email(@email, @name).deliver_now
    #   
    #   # Notify the admin about new subscriber
    #   admin_email = Rails.application.config.podcast_admin_email
    #   AdminMailer.new_subscriber_notification(admin_email, @name, @email).deliver_now if defined?(AdminMailer)
    #   
    #   flash[:success] = "Thank you for subscribing to our podcast newsletter!"
    # rescue => e
    #   Rails.logger.error "Error sending welcome email: #{e.message}"
    #   flash[:error] = "There was a problem with your subscription. Please try again later."
    # end
  end
end