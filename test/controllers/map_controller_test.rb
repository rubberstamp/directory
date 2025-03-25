require "test_helper"

class MapControllerTest < ActionDispatch::IntegrationTest
  test "should get index html" do
    get map_url
    assert_response :success
    assert_select "h1", "Find CFOs Near You"
    assert_select "#map", 1
  end
  
  test "should get index json" do
    # First, create a profile with geocoding
    profile = profiles(:one)
    profile.update(latitude: 40.7128, longitude: -74.0060)
    
    get map_url, as: :json
    assert_response :success
    
    json_response = JSON.parse(response.body)
    assert_kind_of Array, json_response
    
    # Should only include profiles with coordinates
    assert_equal Profile.where.not(latitude: nil, longitude: nil).count, json_response.length
    
    if json_response.length > 0
      # Verify the structure of the json response
      assert_equal profile.id, json_response.first["id"]
      assert_equal profile.name, json_response.first["name"]
      assert_equal profile.latitude.to_s, json_response.first["latitude"].to_s
      assert_equal profile.longitude.to_s, json_response.first["longitude"].to_s
    end
  end
end
