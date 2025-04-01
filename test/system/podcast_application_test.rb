require "application_system_test_case"

class PodcastApplicationTest < ApplicationSystemTestCase
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
    
    # The form is using HTML required attributes, so the browser validation
    # would prevent submission. In system tests, we're just checking the
    # required fields are properly marked in the HTML.
    assert_selector "input[name='guest_message[location]'][required='required']"
    assert_selector "select[name='guest_message[practice_size]'][required='required']"
    assert_selector "input[name='guest_message[specialty]'][required='required']"
    
    # No message should be created
    assert_not GuestMessage.exists?(sender_name: "Test Applicant", sender_email: "applicant@example.com")
  end
end