require "test_helper"

class ProfilesControllerTest < ActionDispatch::IntegrationTest
  setup do
    # Create a profile with a unique email
    @profile = Profile.create!(
      name: "Test Profile",
      headline: "Test Headline",
      bio: "Test bio",
      location: "Test location",
      linkedin_url: "https://linkedin.com/test",
      youtube_url: "https://youtube.com/test",
      email: "profile-#{rand(1000)}@example.com",
      phone: "123-456-7890",
      image_url: "https://example.com/image.jpg"
    )
  end

  test "should get index" do
    get profiles_url
    assert_response :success
  end

  test "should get show" do
    get profile_url(@profile)
    assert_response :success
  end
end
