class ApplicationMailer < ActionMailer::Base
  default from: "info@procurementexpress.com"
  layout "mailer"

  # Override in child classes as needed
  def self.inherited(subclass)
    subclass.default from: Rails.application.config.podcast_email
  end
end
