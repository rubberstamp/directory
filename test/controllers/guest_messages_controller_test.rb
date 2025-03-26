require "test_helper"

class GuestMessagesControllerTest < ActionDispatch::IntegrationTest
  test "should create general inquiry guest message" do
    assert_difference('GuestMessage.count') do
      post guest_messages_url, params: { 
        guest_message: { 
          sender_name: "Test Sender",
          sender_email: "test@example.com",
          subject: "Test Subject",
          message: "This is a test message"
        } 
      }
    end
    
    assert_redirected_to contact_path
    assert_equal "Your message has been sent. Thank you for contacting us!", flash[:notice]
    
    # Check that the message was created with correct attributes
    message = GuestMessage.last
    assert_equal "Test Sender", message.sender_name
    assert_equal "test@example.com", message.sender_email
    assert_equal "Test Subject", message.subject
    assert_equal "This is a test message", message.message
    assert_equal GuestMessage::STATUSES[:new], message.status
    assert_nil message.profile
  end
  
  test "should create guest message for specific profile" do
    profile = profiles(:one)
    
    assert_difference('GuestMessage.count') do
      post profile_guest_messages_url(profile), params: { 
        guest_message: { 
          sender_name: "Test Sender",
          sender_email: "test@example.com",
          subject: "Message for Guest",
          message: "This is a message for a specific guest"
        } 
      }
    end
    
    assert_redirected_to profile_path(profile)
    assert_equal "Your message has been sent to #{profile.name}. Thank you for getting in touch!", flash[:notice]
    
    # Check that the message was created with correct attributes
    message = GuestMessage.last
    assert_equal "Test Sender", message.sender_name
    assert_equal "test@example.com", message.sender_email
    assert_equal "Message for Guest", message.subject
    assert_equal "This is a message for a specific guest", message.message
    assert_equal GuestMessage::STATUSES[:new], message.status
    assert_equal profile.id, message.profile_id
  end
  
  test "should not create guest message with invalid data" do
    assert_no_difference('GuestMessage.count') do
      post guest_messages_url, params: { 
        guest_message: { 
          sender_name: "Test Sender",
          sender_email: "", # Invalid: blank email
          message: "This is a test message"
        } 
      }
    end
    
    assert_response :unprocessable_entity
  end
  
  test "should auto-forward message when profile has auto-forward enabled" do
    profile = profiles(:one)
    profile.update(
      allow_messages: true, 
      auto_forward_messages: true, 
      message_forwarding_email: "guest@example.com"
    )
    
    # Mock the mailer method to verify it's called
    mock = Minitest::Mock.new
    mock.expect :deliver_later, nil
    
    GuestMessageMailer.stub :forward_to_guest, mock do
      post profile_guest_messages_url(profile), params: { 
        guest_message: { 
          sender_name: "Test Sender",
          sender_email: "test@example.com",
          subject: "Auto-forward Test",
          message: "This message should be auto-forwarded"
        } 
      }
    end
    
    assert_redirected_to profile_path(profile)
    
    # Verify the message was marked as forwarded
    message = GuestMessage.last
    assert_equal GuestMessage::STATUSES[:forwarded], message.status
    assert_not_nil message.forwarded_at
    
    mock.verify
  end
  
  test "should not auto-forward when profile has disabled messages" do
    profile = profiles(:one)
    profile.update(
      allow_messages: false, 
      auto_forward_messages: true, 
      message_forwarding_email: "guest@example.com"
    )
    
    post profile_guest_messages_url(profile), params: { 
      guest_message: { 
        sender_name: "Test Sender",
        sender_email: "test@example.com",
        subject: "No Auto-forward Test",
        message: "This message should not be auto-forwarded"
      } 
    }
    
    assert_redirected_to profile_path(profile)
    
    # Verify the message was not forwarded
    message = GuestMessage.last
    assert_equal GuestMessage::STATUSES[:new], message.status
    assert_nil message.forwarded_at
  end
end
