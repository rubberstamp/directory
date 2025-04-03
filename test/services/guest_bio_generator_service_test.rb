require 'test_helper'

# Create a mock profile class for testing
class MockProfile
  attr_accessor :name, :email, :headline, :company, :location, :bio, :website
  
  def initialize(attrs = {})
    attrs.each do |key, value|
      send("#{key}=", value) if respond_to?("#{key}=")
    end
    
    # Default values
    @episodes_list = []
    @episodes_by_date_list = []
    @primary_episodes_list = []
    @secondary_appearances_list = []
    @specializations_list = []
  end
  
  def episodes
    @episodes_list
  end
  
  def episodes=(list)
    @episodes_list = list
  end
  
  def episodes_by_date
    @episodes_by_date_list
  end
  
  def episodes_by_date=(list)
    @episodes_by_date_list = list
  end
  
  def primary_guest_episodes
    @primary_episodes_list
  end
  
  def primary_guest_episodes=(list)
    @primary_episodes_list = list
  end
  
  def secondary_appearances
    @secondary_appearances_list
  end
  
  def secondary_appearances=(list)
    @secondary_appearances_list = list
  end
  
  def specializations
    @specializations_list
  end
  
  def specializations=(list)
    @specializations_list = list
  end
end

class GuestBioGeneratorServiceTest < ActiveSupport::TestCase
  setup do
    # Create a profile with episodes
    @profile = MockProfile.new(
      name: "Test Profile",
      email: "test@example.com",
      bio: nil
    )
    
    # Set up the profile with episodes
    test_episode = Episode.new(title: "Test Episode", summary: "Test summary")
    @profile.episodes = [test_episode]
    @profile.episodes_by_date = [test_episode]
    @profile.primary_guest_episodes = [test_episode]
    @profile.secondary_appearances = []
    @profile.specializations = []
    
    # Create service
    @service = GuestBioGeneratorService.new(@profile)
    @service.stub_response = "This is a generated bio for testing purposes."
  end

  test "generates bio when profile has episodes" do
    # Bio is already nil from setup
    bio = @service.call
    assert_equal "This is a generated bio for testing purposes.", bio
  end
  
  test "returns nil when profile has no episodes" do
    # Create a profile without episodes
    profile_without_episodes = MockProfile.new(
      name: "Profile Without Episodes",
      email: "no-episodes@example.com"
    )
    
    # Empty episodes lists
    profile_without_episodes.episodes = []
    profile_without_episodes.episodes_by_date = []
    
    # Create service
    service = GuestBioGeneratorService.new(profile_without_episodes)
    
    assert_nil service.call
  end
  
  test "service still generates content when profile has bio" do
    # This test confirms that the service itself will still generate a bio
    # (it's the job's responsibility to decide whether to apply it)
    profile_with_bio = MockProfile.new(
      name: "Profile With Bio",
      email: "with-bio@example.com",
      bio: "Existing bio content"
    )
    
    # Set up profile with episodes
    test_episode = Episode.new(title: "Test Episode", summary: "Test summary")
    profile_with_bio.episodes = [test_episode]
    profile_with_bio.episodes_by_date = [test_episode]
    profile_with_bio.primary_guest_episodes = [test_episode]
    profile_with_bio.secondary_appearances = []
    profile_with_bio.specializations = []
    
    # Create service with response stub
    service = GuestBioGeneratorService.new(profile_with_bio)
    service.stub_response = "New bio that shouldn't be used"
    
    # The service itself doesn't enforce the "don't overwrite bios" rule,
    # that's the job's responsibility, so it should still return content
    bio = service.call
    assert_equal "New bio that shouldn't be used", bio
  end
end