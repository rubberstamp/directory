class PodcastMailer < ApplicationMailer
  # Default sender is already set in initializers/postmark.rb

  # Send a welcome email to a new subscriber
  def welcome_email(email, name = nil)
    @name = name || email.split("@").first
    @url = root_url

    mail(
      to: email,
      subject: "Welcome to The Gross Profit Podcast"
    )
  end

  # Send an episode notification to subscribers
  def episode_notification(email, episode)
    @episode = episode
    @name = email.split("@").first
    @episode_url = episode_url(@episode)

    mail(
      to: email,
      subject: "New Episode: #{@episode.title} - The Gross Profit Podcast"
    )
  end

  # Contact confirmation email
  def contact_confirmation(email, message)
    @email = email
    @message = message
    @date = Time.current

    mail(
      to: email,
      subject: "We've received your message - The Gross Profit Podcast"
    )
  end
end
