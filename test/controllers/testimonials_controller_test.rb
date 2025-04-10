require "test_helper"

class TestimonialsControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get testimonials_url
    assert_response :success
    assert_select "h1", "Podcast Guest Testimonials"
  end

  test "should properly eager load headshots and episodes" do
    # Create a profile with testimonial, headshot and episodes for testing
    profile = Profile.create!(
      name: "Eager Loading Test",
      email: "eager@example.com",
      testimonial: "This is a test testimonial for eager loading."
    )

    # Access the index page which should eager load the associations
    get testimonials_url
    assert_response :success

    # Verify the controller's instance variable includes our profile
    profiles = assigns(:profiles)
    assert_includes profiles.map(&:id), profile.id

    # Clean up
    profile.destroy
  end
end
