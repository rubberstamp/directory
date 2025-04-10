require "test_helper"

class GuestApplicationsControllerTest < ActionDispatch::IntegrationTest
  test "should get new" do
    get become_a_guest_path
    assert_response :success
    assert_select "h1", "Become a Guest"
    assert_select "form[action=?]", guest_applications_path
  end

  test "should create applicant profile successfully" do
    assert_difference("Profile.where(status: 'applicant').count") do
      post guest_applications_path, params: {
        profile: {
          name: "Test Applicant",
          email: "applicant@example.com",
          location: "New York, USA",
          headline: "Test Headline",
          company: "Test Company",
          practice_size: "Medium (11-50 employees)",
          podcast_objectives: "I want to share my knowledge"
        }
      }
    end

    assert_redirected_to root_path
    assert_equal "Thank you for your application! We'll review it and get back to you soon.", flash[:success]

    # Check that the created profile has correct data
    profile = Profile.find_by(email: "applicant@example.com")
    assert_equal "applicant", profile.status
    assert_equal "Test Applicant", profile.name
    assert_equal "New York, USA", profile.location
    assert_equal "Medium (11-50 employees)", profile.practice_size
    assert_equal "I want to share my knowledge", profile.podcast_objectives
  end

  test "should fail with invalid data" do
    assert_no_difference("Profile.count") do
      post guest_applications_path, params: {
        profile: {
          name: "Test Invalid",
          # Email missing (required)
          location: "New York, USA"
        }
      }
    end

    assert_response :unprocessable_entity
    assert_select "div", /There was a problem with your application/
  end

  test "should require email field" do
    assert_no_difference("Profile.count") do
      post guest_applications_path, params: {
        profile: {
          name: "Test No Email",
          location: "New York, USA"
        }
      }
    end

    assert_response :unprocessable_entity
    assert_select "div.text-red-700", /There was a problem with your application/
  end
end
