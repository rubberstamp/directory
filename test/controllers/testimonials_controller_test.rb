require "test_helper"

class TestimonialsControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get testimonials_url
    assert_response :success
    assert_select "h1", "Podcast Guest Testimonials"
  end
end