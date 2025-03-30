require "test_helper"

class ContactsControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get contact_path
    assert_response :success
    assert_select "h1", "Contact Us"
  end

  test "should create contact" do
    # Ensure mailer queue is empty before test
    ActionMailer::Base.deliveries.clear

    assert_difference('GuestMessage.count', 0) do # Contacts don't create GuestMessages
      assert_difference('ActionMailer::Base.deliveries.size', 2) do # Expect 2 emails: confirmation + admin
        post contacts_url, params: {
          name: "Test User",
          email: "test@example.com",
          phone: "123-456-7890", 
          message: "This is a test message" 
        }
      end
    end
    
    assert_redirected_to contact_path
    assert_equal "Thank you for your message! We'll get back to you soon.", flash[:success]

    # Check that the confirmation email was sent
    confirmation_email = ActionMailer::Base.deliveries.find { |m| m.to.include?("test@example.com") }
    assert_not_nil confirmation_email, "Confirmation email should have been sent"
    assert_equal "We've received your message - The Gross Profit Podcast", confirmation_email.subject

    # Check that the admin notification was sent
    admin_notification_email = ActionMailer::Base.deliveries.find { |m| m.to.include?(Rails.application.config.podcast_admin_email) }
    assert_not_nil admin_notification_email, "Admin notification email should have been sent"
    assert_equal "New Contact Form Submission - The Gross Profit Podcast", admin_notification_email.subject
  end
  test "should not create contact without required fields" do
    assert_no_difference 'ActionMailer::Base.deliveries.size' do
      post contacts_path, params: { name: "Test User", email: "", message: "" }
    end
    
    assert_redirected_to contact_path
    assert_equal "Please provide your email and message", flash[:error]
  end
  
  test "should subscribe to newsletter" do
    # Ensure mailer queue is empty before test
    ActionMailer::Base.deliveries.clear

    # Currently, subscribe action logs but doesn't send email
    assert_difference('ActionMailer::Base.deliveries.size', 0) do # Expect 0 emails currently
      post subscribe_url, params: { email: "subscriber@example.com", name: "Sub Scriber" }
    end
    assert_redirected_to root_path
    assert_equal "Thank you for subscribing to our podcast newsletter!", flash[:success]

    # NOTE: Email sending is currently disabled in the controller action.
    # Uncomment these assertions when email sending is re-enabled.
    # Check welcome email
    # welcome_email = ActionMailer::Base.deliveries[-2]
    # assert_not_nil welcome_email, "Welcome email should have been sent"
    # assert_equal "Welcome to The Gross Profit Podcast", welcome_email.subject
    # assert_equal ["subscriber@example.com"], welcome_email.to
    
    # Check admin notification
    # admin_notification = ActionMailer::Base.deliveries.last
    # assert_not_nil admin_notification, "Admin notification should have been sent"
    # assert_equal "New Newsletter Subscriber - The Gross Profit Podcast", admin_notification.subject
    # assert_equal [Rails.application.config.podcast_admin_email], admin_notification.to
  end

  test "should not subscribe without email" do
    assert_no_difference 'ActionMailer::Base.deliveries.size' do
      post subscribe_path, params: { name: "Test Subscriber", email: "" }
    end
    
    assert_redirected_to root_path
    assert_equal "Please provide your email to subscribe", flash[:error]
  end
end
