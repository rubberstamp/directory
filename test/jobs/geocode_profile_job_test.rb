require "test_helper"

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
    result = Minitest::Mock.new
    # Mock the result object returned by Geocoder.search().first
    mock_result = Minitest::Mock.new
    # Ensure these return floats
    mock_result.expect :latitude, 40.7128 
    mock_result.expect :longitude, -74.0060
    # Mock address_components_of_type for city and country extraction
    # Need to mock twice as it might be called multiple times within the geocoding logic
    mock_result.expect :address_components_of_type, [{"long_name" => "New York"}], ["locality"]
    mock_result.expect :address_components_of_type, [{"long_name" => "USA"}], ["country"]
    
    # Mock Geocoder.search to return an array containing the mock result only for the correct address
    Geocoder.stub :search, ->(address, *) { 
      if address == profile.location
        [mock_result] # Return the mock result in an array
      else
        [] # Return empty array for other addresses
      end
     } do
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
    
    # Verify the mock expectations were met
    mock_result.verify 
  end

  test "should handle nil search results" do
    profile = @profile
    profile.location = "NonExistentPlace"
    profile.skip_geocoding = true
    profile.save
    
    # Mock Geocoder to return nil results
    Geocoder.stub :search, [nil] do
      # This should not raise an error
      assert_nothing_raised do
        GeocodeProfileJob.perform_now(profile.id)
      end
    end
  end
  
  test "should handle geocoding errors" do
    profile = @profile
    
    # Force an error by making Geocoder.search raise an exception
    Geocoder.stub :search, -> (_) { raise StandardError.new("Test error") } do
      # This should not raise an error
      assert_nothing_raised do
        GeocodeProfileJob.perform_now(profile.id)
      end
    end
  end
end
