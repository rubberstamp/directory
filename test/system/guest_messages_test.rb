require "application_system_test_case"

class GuestMessagesTest < ApplicationSystemTestCase
  setup do
    @profile = profiles(:one)
    @profile.update(
      name: "John Doe",
      allow_messages: true,
      message_forwarding_email: "john@example.com"
    )
  end

  test "sending a message to a guest from profile page" do
    visit profile_path(@profile)
    
    # Click contact button to open modal
    click_on "Contact"
    
    # Fill in contact form
    within "#contact-modal" do
      fill_in "Your Name", with: "Test Sender"
      fill_in "Your Email", with: "test@example.com"
      fill_in "Subject", with: "Test Subject"
      fill_in "Message", with: "This is a test message from system test."
      
      click_on "Send Message"
    end
    
    # Should be redirected back to profile with success message
    assert_current_path profile_path(@profile)
    assert_text "Your message has been sent successfully."
    
    # Check that the message was created in the database
    guest_message = GuestMessage.last
    assert_equal "Test Sender", guest_message.sender_name
    assert_equal "test@example.com", guest_message.sender_email
    assert_equal "Test Subject", guest_message.subject
    assert_equal "This is a test message from system test.", guest_message.message
    assert_equal GuestMessage::STATUSES[:new], guest_message.status
    assert_equal @profile.id, guest_message.profile_id
  end
  
  test "admin can view and manage messages" do
    # Create a test message
    guest_message = GuestMessage.create!(
      sender_name: "Test Sender",
      sender_email: "test@example.com",
      subject: "Test Subject",
      message: "This is a test message.",
      profile: @profile,
      status: GuestMessage::STATUSES[:new]
    )
    
    # Log in as admin
    admin_user = users(:admin)
    visit new_user_session_path
    fill_in "Email", with: admin_user.email
    fill_in "Password", with: "password" # Assuming this is the password in test fixtures
    click_on "Log in"
    
    # Visit admin guest messages page
    visit admin_guest_messages_path
    
    # Should see the message in the list
    assert_text "Test Sender"
    assert_text "Test Subject"
    assert_text @profile.name
    
    # Click to view message details
    click_on "View", match: :first
    
    # Check message details page
    assert_text "Message from Test Sender"
    assert_text "Test Subject"
    assert_text "This is a test message."
    
    # Test marking as read
    select "read", from: "guest_message[status]"
    click_on "Update Status"
    
    assert_text "Guest message was successfully updated"
    
    # Test marking as forwarded
    click_on "Mark as Forwarded"
    
    assert_text "Message marked as forwarded"
    
    # Test adding admin notes
    fill_in "guest_message[admin_notes]", with: "These are admin notes"
    click_on "Update Status"
    
    assert_text "Guest message was successfully updated"
    assert_text "These are admin notes"
    
    # Test message filtering
    visit admin_guest_messages_path
    select "Forwarded", from: "status"
    click_on "Filter"
    
    assert_text "Test Sender"
    
    # Test returning to index
    click_on "Back to Messages"
    assert_current_path admin_guest_messages_path
  end
  
  test "admin can delete a message" do
    # Create a test message
    guest_message = GuestMessage.create!(
      sender_name: "Delete Test",
      sender_email: "delete@example.com",
      subject: "Delete Subject",
      message: "This message should be deleted.",
      profile: @profile,
      status: GuestMessage::STATUSES[:new]
    )
    
    # Log in as admin
    admin_user = users(:admin)
    visit new_user_session_path
    fill_in "Email", with: admin_user.email
    fill_in "Password", with: "password" # Assuming this is the password in test fixtures
    click_on "Log in"
    
    # Visit message details page
    visit admin_guest_message_path(guest_message)
    
    # Delete the message
    accept_confirm do
      click_on "Delete Message"
    end
    
    # Should be redirected to index with success message
    assert_current_path admin_guest_messages_path
    assert_text "Guest message was successfully deleted"
    
    # Message should no longer exist
    assert_not GuestMessage.exists?(guest_message.id)
  end
end