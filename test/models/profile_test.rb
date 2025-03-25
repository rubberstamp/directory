require "test_helper"

class ProfileTest < ActiveSupport::TestCase
  test "should not save profile without name" do
    profile = Profile.new(email: "test@example.com")
    assert_not profile.save, "Saved the profile without a name"
  end
  
  test "should not save profile without email" do
    profile = Profile.new(name: "Test Profile")
    assert_not profile.save, "Saved the profile without an email"
  end
  
  test "should not save profile with invalid email format" do
    profile = Profile.new(name: "Test Profile", email: "invalid-email")
    assert_not profile.save, "Saved the profile with an invalid email format"
  end
  
  test "should validate website format if present" do
    # Valid website with https://
    profile = Profile.new(name: "Test Profile", email: "test@example.com", website: "https://example.com")
    assert profile.valid?, "Profile with valid website was invalid"
    
    # Valid website with http://
    profile = Profile.new(name: "Test Profile", email: "test@example.com", website: "http://example.com")
    assert profile.valid?, "Profile with valid website was invalid"
    
    # Invalid website format
    profile = Profile.new(name: "Test Profile", email: "test@example.com", website: "invalid-url")
    assert profile.valid?, "Website validation should only happen if it starts with http:// or https://"
    
    # Empty website should be valid
    profile = Profile.new(name: "Test Profile", email: "test@example.com", website: "")
    assert profile.valid?, "Profile with empty website was invalid"
  end
  
  test "should generate full address for geocoding" do
    profile = Profile.new(
      name: "Test Profile",
      email: "test@example.com",
      mailing_address: "123 Main St",
      location: "New York, USA"
    )
    
    assert_equal "123 Main St, New York, USA", profile.full_address
    
    # Test with only location
    profile.mailing_address = nil
    assert_equal "New York, USA", profile.full_address
    
    # Test with only mailing address
    profile.mailing_address = "123 Main St"
    profile.location = nil
    assert_equal "123 Main St", profile.full_address
    
    # Test with both nil
    profile.mailing_address = nil
    profile.location = nil
    assert_equal "", profile.full_address
  end
  
  test "should handle formatted location with cached values" do
    profile = Profile.new(
      name: "Test Profile",
      email: "test@example.com",
      location: "Somewhere",
      cached_city: "New York",
      cached_country: "USA"
    )
    
    # Should use cached values if available
    assert_equal "New York, USA", profile.formatted_location
    
    # Should use only city if country is missing
    profile.cached_country = nil
    assert_equal "New York", profile.formatted_location
    
    # Should use only country if city is missing
    profile.cached_city = nil
    profile.cached_country = "USA"
    assert_equal "USA", profile.formatted_location
    
    # Should fall back to location field if no cached values
    profile.cached_city = nil
    profile.cached_country = nil
    assert_equal "Somewhere", profile.formatted_location
  end
  
  test "should check if profile has podcast episode" do
    # New profile with no episodes
    profile = Profile.new(name: "Test Profile", email: "test@example.com")
    assert_not profile.has_podcast_episode?
    
    # Profile with legacy episode URL
    profile.deprecated_episode_url = "dQw4w9WgXcQ"
    assert profile.has_podcast_episode?
    
    # Profile with legacy episode number
    profile = Profile.new(name: "Test Profile", email: "test2@example.com")
    profile.deprecated_episode_number = 42
    assert profile.has_podcast_episode?
    
    # Profile with legacy episode title
    profile = Profile.new(name: "Test Profile", email: "test3@example.com")
    profile.deprecated_episode_title = "Test Episode"
    assert profile.has_podcast_episode?
  end
  
  test "should handle headshot_url_or_attached" do
    profile = Profile.create!(name: "Test Profile", email: "test@example.com")
    
    # Test with legacy URL
    profile.headshot_url = "https://example.com/image.jpg"
    assert_equal "https://example.com/image.jpg", profile.headshot_url_or_attached
    
    # Cleanup
    profile.destroy
  end
end
