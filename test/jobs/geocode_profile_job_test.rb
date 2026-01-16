require "test_helper"
require "ostruct" # Add this line

class GeocodeProfileJobTest < ActiveJob::TestCase
  include ActiveJob::TestHelper

  # Create a test profile instead of using fixture
  setup do
    @profile = Profile.create!(
      name: "Test Geocode Profile",
      email: "geocode-test@example.com",
      location: "New York, NY",
      skip_geocoding: true
    )
  end

  teardown do
    @profile.destroy if @profile.persisted?
  end

  test "should geocode profile" do
    profile = @profile
    profile.location = "New York, NY"
    profile.skip_geocoding = true
    profile.save

    # Mock Geocoder to return predictable results
    # Mock the result object using OpenStruct for simplicity
    # The job expects result.address to be a Hash with "city" and "country" keys
    mock_result = OpenStruct.new(
      latitude: 40.7128,
      longitude: -74.0060,
      address: { "city" => "New York", "country" => "USA" }
    )

    # Mock Geocoder.search to return the mock result when the correct address is searched
    Geocoder.stub :search, ->(address, *) { address == profile.location ? [ mock_result ] : [] } do
      # Perform the job
      GeocodeProfileJob.perform_now(profile.id)
    end

    # Reload the profile
    profile.reload

    # Verify the coordinates and cached location data were updated
    assert_in_delta 40.7128, profile.latitude # Use assert_in_delta for floats
    assert_in_delta -74.0060, profile.longitude
    assert_equal "New York", profile.cached_city
    assert_equal "USA", profile.cached_country

    # No verify needed for OpenStruct/lambda stub
  end

  test "should handle nil search results" do
    profile = @profile
    profile.location = "NonExistentPlace"
    profile.skip_geocoding = true
    profile.save

    # Mock Geocoder to return nil results
    Geocoder.stub :search, [ nil ] do
      # This should not raise an error
      assert_nothing_raised do
        GeocodeProfileJob.perform_now(profile.id)
      end
    end
  end

  test "should handle geocoding errors" do
    profile = @profile

    # Force an error by making Geocoder.search raise an exception
    Geocoder.stub :search, ->(_) { raise StandardError.new("Test error") } do
      # This should not raise an error
      assert_nothing_raised do
        GeocodeProfileJob.perform_now(profile.id)
      end
    end
  end
end
