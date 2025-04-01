require 'test_helper'

class GuestApplicationFeatureTest < ActionDispatch::IntegrationTest
  test "complete guest application workflow" do
    # Step 1: Create an applicant through the form
    get become_a_guest_path
    assert_response :success
    
    # Submit the application
    post guest_applications_path, params: {
      profile: {
        name: "Integration Test Applicant",
        email: "integration-applicant@example.com",
        location: "Test City, Test Country",
        headline: "Integration Test Position",
        company: "Integration Test Company",
        practice_size: "Medium (11-50 employees)",
        podcast_objectives: "Integration test objectives"
      }
    }
    
    # Check redirect and flash message
    assert_redirected_to root_path
    follow_redirect!
    assert_select "div", /Thank you for your application/
    
    # Step 2: Find the newly created applicant
    applicant = Profile.find_by(email: "integration-applicant@example.com")
    assert_not_nil applicant
    assert_equal "applicant", applicant.status
    
    # Step 3: Verify the applicant is not visible on the public listing
    get profiles_path
    assert_response :success
    assert_no_match(/Integration Test Applicant/, response.body)
    
    # Step 4: Admin logs in and approves the applicant
    admin = User.create!(
      email: "integration-admin@example.com", 
      password: 'password123', 
      password_confirmation: 'password123',
      admin: true
    )
    
    # Sign in as admin
    post user_session_path, params: { 
      user: { email: admin.email, password: 'password123' } 
    }
    
    # View the applicants list
    get admin_profiles_path(status: "applicant")
    assert_response :success
    
    # Approve the applicant
    patch admin_profile_path(applicant), params: {
      profile: {
        status: "guest"
      }
    }
    
    # Verify status changed
    applicant.reload
    assert_equal "guest", applicant.status
    
    # Step 5: Verify the now-guest is visible on the public listing
    get profiles_path
    assert_response :success
    assert_match(/Integration Test Applicant/, response.body)
    
    # Clean up
    applicant.destroy
    admin.destroy
  end
end