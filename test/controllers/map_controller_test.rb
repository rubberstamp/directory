require "test_helper"

class MapControllerTest < ActionDispatch::IntegrationTest
  test "should get index html" do
    get map_url
    assert_response :success
    assert_select "h1", "Find CFOs Near You"
    assert_select "#map", 1
  end
  
  test "should get index json" do
    # Create a test profile with geo coordinates
    profile = Profile.create!(
      name: "Test Profile", 
      email: "test@example.com",
      latitude: 40.7128, 
      longitude: -74.0060
    )
    
    get map_url, as: :json
    assert_response :success
    
    json_response = JSON.parse(response.body)
    assert_kind_of Array, json_response
    
    # Should only include profiles with coordinates
    assert_equal Profile.where.not(latitude: nil, longitude: nil).count, json_response.length
    
    if json_response.length > 0
      # Verify the structure of the json response
      profile_in_json = json_response.find { |p| p["id"] == profile.id }
      assert_not_nil profile_in_json
      assert_equal profile.name, profile_in_json["name"]
      assert_equal profile.latitude.to_s, profile_in_json["latitude"].to_s
      assert_equal profile.longitude.to_s, profile_in_json["longitude"].to_s
    end
    
    # Clean up
    profile.destroy
  end
end
