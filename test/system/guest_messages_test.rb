require "application_system_test_case"

class GuestMessagesTest < ApplicationSystemTestCase
  def setup_profile_for_message_tests
    # Create or update a profile for tests that need it
    @profile = Profile.find_or_create_by(email: "john@example.com") do |p|
      p.name = "John Doe"
    end
    
    @profile.update(
      allow_messages: true,
      message_forwarding_email: "john@example.com"
    )
  end
  
  setup do
    # Don't automatically set up profile for podcast application tests
    unless self.method_name.include?('submitting_a_podcast')
      setup_profile_for_message_tests
    end
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
  
  test "submitting a podcast guest application via /apply" do
    visit apply_path
    
    # Verify we're on the application page
    assert_text "Apply to be a Podcast Guest"
    assert_text "We're looking for accounting and finance professionals"
    
    # Fill in the application form using field IDs
    fill_in "guest_message_sender_name", with: "Test Applicant"
    fill_in "guest_message_sender_email", with: "applicant@example.com"
    fill_in "guest_message_location", with: "London, UK"
    select "Medium (11-50 employees)", from: "guest_message_practice_size"
    fill_in "guest_message_specialty", with: "Tax Advisory"
    fill_in "guest_message_subject", with: "International Tax Planning"
    fill_in "guest_message_message", with: "I'm a tax professional with 10 years of experience in international taxation."
    
    # Submit the application
    click_button "Submit Application"
    
    # Should be redirected with success message
    assert_text "Your message has been sent successfully."
    
    # Verify the application was created as a guest message
    guest_message = GuestMessage.last
    assert_equal "Test Applicant", guest_message.sender_name
    assert_equal "applicant@example.com", guest_message.sender_email
    assert_equal "International Tax Planning", guest_message.subject
    assert_equal "I'm a tax professional with 10 years of experience in international taxation.", guest_message.message
    assert_equal "London, UK", guest_message.location
    assert_equal "Tax Advisory", guest_message.specialty
    assert_equal "Medium", guest_message.practice_size
    assert guest_message.is_podcast_application
    assert_equal GuestMessage::STATUSES[:new], guest_message.status
  end
  
  test "submitting an invalid podcast application" do
    visit apply_path
    
    # Fill in the form with incomplete data (missing required fields)
    fill_in "guest_message_sender_name", with: "Test Applicant"
    fill_in "guest_message_sender_email", with: "applicant@example.com"
    # Deliberately skipping location, practice size, and specialty (required fields)
    fill_in "guest_message_message", with: "I'm a professional."
    
    # Submit the application
    click_button "Submit Application"
    
    # Should see error messages
    assert_text "There was a problem sending your message:"
    assert_text "Location can't be blank"
    assert_text "Practice size can't be blank"
    assert_text "Specialty can't be blank"
    
    # No message should be created
    assert_not GuestMessage.exists?(sender_name: "Test Applicant", sender_email: "applicant@example.com")
  end
end