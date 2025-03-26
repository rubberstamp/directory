# Preview all emails at http://localhost:3000/rails/mailers/guest_message_mailer
class GuestMessageMailerPreview < ActionMailer::Preview
  # Helper method to create a sample guest message
  def sample_guest_message(options = {})
    profile = Profile.find_by(name: "John Doe") || 
              Profile.create!(
                name: "John Doe",
                email: "john@example.com",
                message_forwarding_email: "john@example.com",
                allow_messages: true,
                auto_forward_messages: false
              )
    
    GuestMessage.new(
      sender_name: "Jane Smith",
      sender_email: "jane@example.com",
      subject: "Sample Message for Preview",
      message: "This is a sample message content for email preview purposes.\n\nIt includes multiple paragraphs to show how the formatting will appear in the email template.\n\nThank you for your attention to this matter.",
      profile: options[:general] ? nil : profile,
      status: GuestMessage::STATUSES[:new]
    )
  end
  
  # Preview this email at http://localhost:3000/rails/mailers/guest_message_mailer/sender_confirmation
  def sender_confirmation
    GuestMessageMailer.sender_confirmation(sample_guest_message)
  end

  # Preview this email at http://localhost:3000/rails/mailers/guest_message_mailer/admin_notification
  def admin_notification
    GuestMessageMailer.admin_notification(sample_guest_message)
  end

  # Preview this email at http://localhost:3000/rails/mailers/guest_message_mailer/forward_to_guest
  def forward_to_guest
    GuestMessageMailer.forward_to_guest(sample_guest_message)
  end
  
  # Preview this email at http://localhost:3000/rails/mailers/guest_message_mailer/forward_general_inquiry
  def forward_general_inquiry
    GuestMessageMailer.forward_to_guest(sample_guest_message(general: true))
  end
end
