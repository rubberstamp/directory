class AdminMailer < ApplicationMailer
  # Notify admin about new contact form submission
  def new_contact_notification(admin_email, name, email, phone, message)
    @name = name
    @email = email
    @phone = phone
    @message = message
    @date = Time.current
    
    mail(
      to: admin_email,
      subject: "New Contact Form Submission - The Gross Profit Podcast"
    )
  end
  
  # Notify admin about new subscriber
  def new_subscriber_notification(admin_email, name, email)
    @name = name || email.split('@').first
    @email = email
    @date = Time.current
    
    mail(
      to: admin_email,
      subject: "New Newsletter Subscriber - The Gross Profit Podcast"
    )
  end
end