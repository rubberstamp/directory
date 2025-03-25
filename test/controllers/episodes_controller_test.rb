require "test_helper"

class EpisodesControllerTest < ActionDispatch::IntegrationTest
  setup do
    # Create a profile for testing
    @profile = Profile.create!(
      name: "Test Profile",
      email: "test-#{rand(1000)}@example.com" # Make email unique
    )
    
    # Create an episode with a profile
    @episode_with_profile = Episode.create!(
      number: 888,
      title: "Test Episode With Profile",
      video_id: "test_video_id_#{rand(1000)}",
      air_date: Date.today,
      notes: "Test notes"
    )
    
    # Create a relationship between the profile and episode
    ProfileEpisode.create!(
      profile: @profile,
      episode: @episode_with_profile,
      is_primary_guest: true,
      appearance_type: "Guest",
      notes: "Test notes"
    )
    
    # Create an episode without any associated profiles
    @episode_without_profiles = Episode.create!(
      number: 999,
      title: "Episode Without Profiles",
      video_id: "no_profile_video_id_#{rand(1000)}", # Ensure uniqueness
      air_date: Date.today,
      notes: "Test notes"
    )
  end

  test "should get index and only include episodes with profiles" do
    get episodes_url
    assert_response :success
    
    # Only episodes with associated profiles should be in the index
    assert_select "h3", text: "No episodes found", count: 0
    assert_select "a", text: /View All Episodes on YouTube/
  end

  test "should get show for episode with profiles" do
    get episode_url(@episode_with_profile)
    assert_response :success
  end
  
  test "should redirect from show for episode without profiles" do
    get episode_url(@episode_without_profiles)
    assert_redirected_to episodes_path
    assert_equal "This episode is not currently available.", flash[:alert]
  end
end
