require "application_system_test_case"

class GuestApplicationsTest < ApplicationSystemTestCase
  test "visiting the guest application form" do
    visit root_url
    assert_selector "a", text: "Become a Guest"
    click_on "Become a Guest"
    
    assert_selector "h1", text: "Become a Guest"
    assert_selector "form"
  end
  
  test "submitting a valid guest application" do
    visit become_a_guest_path
    
    # Fill in the form with valid data
    fill_in "Name", with: "Test Applicant"
    fill_in "Email", with: "test-applicant@example.com"
    fill_in "Location", with: "New York, USA"
    select "Medium (11-50 employees)", from: "Practice Size"
    fill_in "Professional Title/Headline", with: "CEO"
    fill_in "Your Objectives for Being on the Podcast", with: "I want to share industry insights"
    fill_in "LinkedIn Profile", with: "https://linkedin.com/in/test-applicant"
    
    # Submit the form
    click_on "Submit Application"
    
    # Verify success message is shown
    assert_text "Thank you for your application! We'll review it and get back to you soon."
    
    # Verify the applicant was created in the database
    applicant = Profile.find_by(email: "test-applicant@example.com")
    assert_not_nil applicant
    assert_equal "applicant", applicant.status
    assert_equal "Test Applicant", applicant.name
    assert_equal "New York, USA", applicant.location
    assert_equal "Medium (11-50 employees)", applicant.practice_size
    assert_equal "I want to share industry insights", applicant.podcast_objectives
    
    # Clean up
    applicant.destroy
  end
  
  test "submitting an invalid application shows errors" do
    visit become_a_guest_path
    
    # Submit without filling required fields
    click_on "Submit Application"
    
    # Check that errors are shown
    assert_text "There was a problem with your application"
    assert_text "Name can't be blank"
    assert_text "Email can't be blank"
  end
  
  test "top navigation shows Become a Guest button for non-admin users" do
    visit root_url
    
    # Non-admin user should see Become a Guest button
    assert_selector "a.bg-brand-orange", text: "Become a Guest"
    
    # Clean up any test data
  end
end