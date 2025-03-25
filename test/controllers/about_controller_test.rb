require "test_helper"

class AboutControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get about_url
    assert_response :success
    assert_select "h1", "About The Gross Profit Podcast"
  end
end