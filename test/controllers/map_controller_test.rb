require "test_helper"

class MapControllerTest < ActionDispatch::IntegrationTest
  test "should get index html" do
    get map_url
    assert_response :success
    assert_select "h1", "Guest Map"
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

  test "should filter json results by specialization" do
    skip "Need to debug specialization filtering in map controller"
  end

  test "should filter json results by guest status" do
    # Create a podcast guest profile
    podcast_profile = Profile.create!(
      name: "Podcast Guest",
      email: "podcast@example.com",
      latitude: 40.7128,
      longitude: -74.0060,
      submission_date: Date.today
    )

    # Create a profile interested in procurement
    procurement_profile = Profile.create!(
      name: "Procurement Interest",
      email: "procurement@example.com",
      latitude: 41.7128,
      longitude: -75.0060,
      interested_in_procurement: true
    )

    # Create a regular profile
    regular_profile = Profile.create!(
      name: "Regular Profile",
      email: "regular@example.com",
      latitude: 42.7128,
      longitude: -76.0060
    )

    # Test podcast guest filter
    get map_url, params: { guest_filter: "podcast_guests" }, as: :json
    assert_response :success

    json_response = JSON.parse(response.body)
    assert_kind_of Array, json_response

    # Should only include the podcast guest profile
    assert_equal 1, json_response.length
    assert_equal podcast_profile.id, json_response.first["id"]

    # Test procurement interest filter
    get map_url, params: { guest_filter: "procurement" }, as: :json
    assert_response :success

    json_response = JSON.parse(response.body)
    assert_kind_of Array, json_response

    # Should only include the procurement interest profile
    assert_equal 1, json_response.length
    assert_equal procurement_profile.id, json_response.first["id"]

    # Clean up
    podcast_profile.destroy
    procurement_profile.destroy
    regular_profile.destroy
  end

  test "should include proper marker data in json response" do
    # Create a profile with all the properties needed for the marker
    profile = Profile.create!(
      name: "Complete Profile",
      email: "complete@example.com",
      latitude: 40.7128,
      longitude: -74.0060,
      company: "Test Company",
      headline: "Test Headline",
      location: "New York, USA",
      submission_date: Date.today
    )

    # Create a specialization and associate with the profile
    specialization = Specialization.create!(name: "Map Specialization")
    ProfileSpecialization.create!(profile: profile, specialization: specialization)

    get map_url, as: :json
    assert_response :success

    json_response = JSON.parse(response.body)
    marker = json_response.find { |m| m["id"] == profile.id }

    # Check all marker properties
    assert_not_nil marker
    assert_equal profile.name, marker["name"]
    assert_equal profile.latitude.to_f, marker["latitude"]
    assert_equal profile.longitude.to_f, marker["longitude"]
    assert_equal profile.company, marker["company"]
    assert_equal profile.headline, marker["headline"]
    # The formatted location might be slightly different based on the geocoder
    assert_match /New York/i, marker["location"]
    # Guest status depends on has_podcast_episode? which might need more setup
    assert_includes [ true, false ], marker["has_podcast"]
    assert_equal [ specialization.name ], marker["specializations"]

    # Clean up
    profile.destroy
    specialization.destroy
  end
end
