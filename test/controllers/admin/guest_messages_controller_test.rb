require "test_helper"

class Admin::GuestMessagesControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    # Use helper to sign in admin
    sign_in_as_admin # This sets @admin

    # Create necessary records manually
    @profile = Profile.create!(
      name: "Test Profile for Admin Messages",
      email: "admin-msg-profile@example.com",
      allow_messages: true,
      message_forwarding_email: "guest-fwd@example.com"
    )
    @guest_message = GuestMessage.create!(
      sender_name: "Admin Test Sender",
      sender_email: "admin-test@example.com",
      subject: "Test Subject",
      message: "This is a test message",
      profile: @profile,
      status: GuestMessage::STATUSES[:new]
    )
  end
  
  test "should get index" do
    get admin_guest_messages_url
    assert_response :success
  end
  
  test "should filter index by status" do
    get admin_guest_messages_url, params: { status: GuestMessage::STATUSES[:new] }
    assert_response :success
  end
  
  test "should filter index by profile" do
    get admin_guest_messages_url, params: { profile_id: @profile.id }
    assert_response :success
  end
  
  test "should show guest message" do
    get admin_guest_message_url(@guest_message)
    assert_response :success
  end
  
  test "should get edit form" do
    get edit_admin_guest_message_url(@guest_message)
    assert_response :success
  end
  
  test "should update guest message" do
    patch admin_guest_message_url(@guest_message), params: {
      guest_message: {
        status: GuestMessage::STATUSES[:read],
        admin_notes: "These are admin notes for testing"
      }
    }
    
    assert_redirected_to admin_guest_message_url(@guest_message)
    
    @guest_message.reload
    assert_equal GuestMessage::STATUSES[:read], @guest_message.status
    assert_equal "These are admin notes for testing", @guest_message.admin_notes
  end
  
  test "should destroy guest message" do
    assert_difference('GuestMessage.count', -1) do
      delete admin_guest_message_url(@guest_message)
    end
    
    assert_redirected_to admin_guest_messages_url
  end
  
  test "should mark guest message as forwarded (email delivery disabled)" do
    @profile.update(
      allow_messages: true,
      message_forwarding_email: "guest@example.com"
    )
    
    post forward_admin_guest_message_url(@guest_message)
    
    assert_redirected_to admin_guest_message_url(@guest_message)
    
    # Verify that the correct notice message is displayed
    assert_equal "Message marked as forwarded. (Note: Actual email delivery is currently disabled)", flash[:notice]
    
    @guest_message.reload
    assert_equal GuestMessage::STATUSES[:forwarded], @guest_message.status
    assert_not_nil @guest_message.forwarded_at
  end
  
  test "should not forward when profile disallows messages" do
    @profile.update(
      allow_messages: false,
      message_forwarding_email: "guest@example.com"
    )
    
    post forward_admin_guest_message_url(@guest_message)
    
    assert_redirected_to admin_guest_message_url(@guest_message)
    
    # Flash should contain an error message
    assert_equal "Unable to forward message. Guest has disabled messages or has no forwarding email.", flash[:alert]
    
    @guest_message.reload
    assert_equal GuestMessage::STATUSES[:new], @guest_message.status
    assert_nil @guest_message.forwarded_at
  end
  
  test "should require admin login" do
    sign_out @admin
    
    get admin_guest_messages_url
    assert_redirected_to new_user_session_path
  end
end
