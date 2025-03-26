class GuestMessageMailer < ApplicationMailer
  # Confirmation email to sender
  def sender_confirmation(guest_message)
    @guest_message = guest_message
    @profile = guest_message.profile
    
    mail(
      to: guest_message.sender_email,
      subject: "We've received your message - The Gross Profit Podcast"
    )
  end

  # Notification to admin about a new message
  def admin_notification(guest_message)
    @guest_message = guest_message
    @profile = guest_message.profile
    
    subject_line = if @guest_message.subject.present?
      "New Guest Message: #{@guest_message.subject}"
    else
      "New Guest Message - The Gross Profit Podcast"
    end
    
    mail(
      to: Rails.application.config.podcast_admin_email,
      subject: subject_line
    )
  end

  # Forward message to guest
  def forward_to_guest(guest_message)
    @guest_message = guest_message
    @profile = guest_message.profile
    
    return unless @profile
    
    # Use the effective forwarding email determined by the profile
    recipient_email = @profile.effective_forwarding_email
    
    subject_line = if @guest_message.subject.present?
      "#{@guest_message.subject} - from #{guest_message.sender_name} via The Gross Profit Podcast"
    else
      "Message from #{guest_message.sender_name} via The Gross Profit Podcast"
    end
    
    mail(
      to: recipient_email,
      reply_to: guest_message.sender_email,
      subject: subject_line,
    )
  end
end