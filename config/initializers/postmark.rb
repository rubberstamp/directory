# Postmark configuration initializer

# Set ActionMailer to use Postmark delivery method
ActionMailer::Base.delivery_method = :postmark
ActionMailer::Base.postmark_settings = {
  api_token: 'c4555d97-5a7c-4468-9169-439d8c0b8be1'
}

# Set ActionMailer's default sender
ActionMailer::Base.default(
  from: 'podcast@procurementexpress.com',
  reply_to: 'podcast@procurementexpress.com'
)