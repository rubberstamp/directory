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
    @name = name || email.split("@").first
    @email = email
    @date = Time.current

    mail(
      to: admin_email,
      subject: "New Newsletter Subscriber - The Gross Profit Podcast"
    )
  end

  # Notify admin about new event registration
  def event_registration_notification(name, email, company, message, event_date)
    @name = name
    @email = email
    @company = company
    @message = message
    @event_date = event_date
    @date = Time.current

    mail(
      to: "james.kennedy@procurementexpress.com",
      subject: "New Mastermind Registration - The Gross Profit Podcast"
    )
  end
end
