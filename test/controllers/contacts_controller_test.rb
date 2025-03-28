require "test_helper"

class ContactsControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get contact_path
    assert_response :success
    assert_select "h1", "Contact Us"
  end
  test "should create contact" do
    assert_difference 'ActionMailer::Base.deliveries.size', 2 do
      post contacts_path, params: { 
        name: "Test User", 
        email: "test@example.com", 
        phone: "123-456-7890", 
        message: "This is a test message" 
      }
    end
    
    assert_redirected_to contact_path
    assert_equal "Thank you for your message! We'll get back to you soon.", flash[:success]
    
    # Check that the confirmation email was sent
    confirmation_email = ActionMailer::Base.deliveries[-2]
    assert_equal "We've received your message - The Gross Profit Podcast", confirmation_email.subject
    assert_equal ["test@example.com"], confirmation_email.to
    
    # Check that the admin notification was sent
    admin_email = ActionMailer::Base.deliveries.last
    assert_equal "New Contact Form Submission - The Gross Profit Podcast", admin_email.subject
    assert_equal ["podcast@procurementexpress.com"], admin_email.to
  end
  
  test "should not create contact without required fields" do
    assert_no_difference 'ActionMailer::Base.deliveries.size' do
      post contacts_path, params: { name: "Test User", email: "", message: "" }
    end
    
    assert_redirected_to contact_path
    assert_equal "Please provide your email and message", flash[:error]
  end
  
  test "should subscribe to newsletter" do
    assert_difference 'ActionMailer::Base.deliveries.size', 2 do
      post subscribe_path, params: { name: "Test Subscriber", email: "subscriber@example.com" }
    end
    
    assert_redirected_to root_path
    assert_equal "Thank you for subscribing to our podcast newsletter!", flash[:success]
    
    # Check welcome email
    welcome_email = ActionMailer::Base.deliveries[-2]
    assert_equal "Welcome to The Gross Profit Podcast", welcome_email.subject
    assert_equal ["subscriber@example.com"], welcome_email.to
    
    # Check admin notification
    admin_notification = ActionMailer::Base.deliveries.last
    assert_equal "New Newsletter Subscriber - The Gross Profit Podcast", admin_notification.subject
    assert_equal ["podcast@procurementexpress.com"], admin_notification.to
  end
  
  test "should not subscribe without email" do
    assert_no_difference 'ActionMailer::Base.deliveries.size' do
      post subscribe_path, params: { name: "Test Subscriber", email: "" }
    end
    
    assert_redirected_to root_path
    assert_equal "Please provide your email to subscribe", flash[:error]
  end
end