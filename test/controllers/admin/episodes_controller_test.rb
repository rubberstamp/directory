require "test_helper"
require 'minitest/mock' # Add this line to require the mock library

class Admin::EpisodesControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    # Use the helper to create/sign in admin user. It sets @admin.
    sign_in_as_admin 
    
    # Create a default episode for tests that need one
    @episode = Episode.create!(
      number: 1, 
      title: "Default Test Episode", 
      video_id: "default_test_id", 
      air_date: Date.today
    )
  end

  test "should get index" do
    get admin_episodes_path
    assert_response :success
  end
  
  test "should get new" do
    get new_admin_episode_path
    assert_response :success
  end
  
  test "should create episode" do
    assert_difference('Episode.count') do
      post admin_episodes_path, params: { 
        episode: { 
          number: 999, 
          title: "Test Episode", 
          video_id: "uniqueID123", 
          air_date: Date.today 
        } 
      }
    end
    
    assert_redirected_to admin_episode_path(Episode.last)
  end
  
  test "should show episode" do
    get admin_episode_path(@episode)
    assert_response :success
  end
  
  test "should get edit" do
    get edit_admin_episode_path(@episode)
    assert_response :success
  end
  
  test "should update episode" do
    patch admin_episode_path(@episode), params: { 
      episode: { 
        title: "Updated Title" 
      } 
    }
    assert_redirected_to admin_episode_path(@episode)
    @episode.reload
    assert_equal "Updated Title", @episode.title
  end
  
  test "should destroy episode" do
    assert_difference('Episode.count', -1) do
      delete admin_episode_path(@episode)
    end
    
    assert_redirected_to admin_episodes_path
  end
  
  test "should get template CSV" do
    get template_admin_episodes_path
    assert_response :success
    assert_equal "text/csv", @response.media_type
    assert_match "Episode Number", @response.body
  end
  
  test "should export episodes as CSV" do
    get export_admin_episodes_path
    assert_response :success
    assert_equal "text/csv", @response.media_type
    assert_match "Episode Number", @response.body
    assert_match @episode.title, @response.body
  end

  test "should export filtered episodes" do
    sign_in_as_admin # Ensure admin is signed in for this test

    # Create a unique episode for this test
    unique_episode = Episode.create!(
      number: 999,
      title: "UniqueExportTest",
      video_id: "unique_test_123"
    )
    
    # Export with filter
    get export_admin_episodes_path(search: "UniqueExportTest")
    assert_response :success
    assert_equal "text/csv", @response.media_type
    
    # Should include the filtered episode
    assert_match "UniqueExportTest", @response.body
    
    # Should not include other episodes
    assert_no_match @episode.title, @response.body
    
    # Clean up
    unique_episode.destroy
  end
  
  test "should import episodes from CSV" do
    # Create a test CSV file
    file = Tempfile.new(['episodes', '.csv'])
    file.write(<<~CSV)
      Guest Name,Episode Number,Episode Title,Video ID,Episode Date,Notes,Duration,Thumbnail URL
      Guest One,101,Test Import Episode,newvideoid123,2025-01-01,Test notes,1800,https://example.com/thumb.jpg
    CSV
    file.rewind
    
    assert_difference('Episode.count') do
      post import_admin_episodes_path, params: { 
        file: fixture_file_upload(file.path, 'text/csv'), 
        update_existing: "1" 
      }
    end
    
    assert_redirected_to admin_episodes_path
    assert_not_nil flash[:notice]
    
    # Verify the episode was created
    episode = Episode.find_by(video_id: 'newvideoid123')
    assert_not_nil episode
    assert_equal 101, episode.number
    assert_equal 'Test Import Episode', episode.title
    
    file.close
    file.unlink
  end
  
  test "should update existing episode when video ID matches" do
    episode = Episode.create!(
      number: 200,
      title: "Original Title",
      video_id: "existingid456",
      air_date: Date.yesterday
    )
    
    # Create a test CSV file with the same video ID but updated info
    file = Tempfile.new(['episodes', '.csv'])
    file.write(<<~CSV)
      Guest Name,Episode Number,Episode Title,Video ID,Episode Date,Notes,Duration,Thumbnail URL
      Guest Two,200,Updated Title,existingid456,2025-01-02,New notes,2400,https://example.com/new.jpg
    CSV
    file.rewind
    
    assert_no_difference('Episode.count') do
      post import_admin_episodes_path, params: { 
        file: fixture_file_upload(file.path, 'text/csv'), 
        update_existing: "1" 
      }
    end
    
    assert_redirected_to admin_episodes_path
    assert_not_nil flash[:notice]
    
    # Verify the episode was updated
    episode.reload
    assert_equal 'Updated Title', episode.title
    assert_equal 'New notes', episode.notes
    assert_equal Date.parse('2025-01-02'), episode.air_date
    
    file.close
    file.unlink
  end
  
  test "should update existing episode when episode number matches" do
    episode = Episode.create!(
      number: 500,
      title: "Original Title By Number",
      video_id: "oldvideoid888",
      air_date: Date.yesterday
    )
    
    # Create a test CSV file with same number but different video_id
    file = Tempfile.new(['episodes', '.csv'])
    file.write(<<~CSV)
      Guest Name,Episode Number,Episode Title,Video ID,Episode Date,Notes,Duration,Thumbnail URL
      Guest Three,500,Updated By Number,newvideoid999,2025-02-15,Updated via number match,3000,https://example.com/updated.jpg
    CSV
    file.rewind
    
    assert_no_difference('Episode.count') do
      post import_admin_episodes_path, params: { 
        file: fixture_file_upload(file.path, 'text/csv'), 
        update_existing: "1" 
      }
    end
    
    assert_redirected_to admin_episodes_path
    assert_not_nil flash[:notice]
    
    # Verify the episode was updated
    episode.reload
    assert_equal 'Updated By Number', episode.title
    assert_equal 'Updated via number match', episode.notes
    assert_equal 'newvideoid999', episode.video_id  # Video ID should be updated
    assert_equal Date.parse('2025-02-15'), episode.air_date
    
    file.close
    file.unlink
  end
  
  test "should handle conflicting episode numbers when updating by video ID" do
    # Create two episodes: one to update and one that causes the number conflict
    episode_to_update = Episode.create!(
      number: 600,
      title: "Original To Update",
      video_id: "update_conflict_video",
      air_date: Date.yesterday
    )
    
    Episode.create!(
      number: 601,  # This number will be the conflict
      title: "Existing Number",
      video_id: "existing_number_video",
      air_date: Date.yesterday
    )
    
    # Create a test CSV file that tries to update episode_to_update's number to 601 (which already exists)
    file = Tempfile.new(['episodes', '.csv'])
    file.write(<<~CSV)
      Guest Name,Episode Number,Episode Title,Video ID,Episode Date,Notes
      Guest Four,601,Conflicting Update,update_conflict_video,2025-03-01,This should fail
    CSV
    file.rewind
    
    assert_no_difference('Episode.count') do
      post import_admin_episodes_path, params: { 
        file: fixture_file_upload(file.path, 'text/csv'), 
        update_existing: "1" 
      }
    end
    
    assert_redirected_to admin_episodes_path
    
    # Verify the episode was NOT updated (number stayed the same)
    episode_to_update.reload
    assert_equal 600, episode_to_update.number
    assert_equal "Original To Update", episode_to_update.title
    
    file.close
    file.unlink
  end
  
  test "should skip existing episode when update_existing is false" do
    episode = Episode.create!(
      number: 300,
      title: "Original Title",
      video_id: "existingid789",
      air_date: Date.yesterday
    )
    
    # Create a test CSV file with the same video ID but updated info
    file = Tempfile.new(['episodes', '.csv'])
    file.write(<<~CSV)
      Guest Name,Episode Number,Episode Title,Video ID,Episode Date,Notes,Duration,Thumbnail URL
      Guest Three,300,New Title,existingid789,2025-01-03,Some notes,1500,https://example.com/img.jpg
    CSV
    file.rewind
    
    assert_no_difference('Episode.count') do
      post import_admin_episodes_path, params: { 
        file: fixture_file_upload(file.path, 'text/csv'), 
        update_existing: "0" # Don't update existing
      }
    end
    
    assert_redirected_to admin_episodes_path
    assert_not_nil flash[:notice]
    
    # Verify the episode was NOT updated
    episode.reload
    assert_equal 'Original Title', episode.title
    assert_nil episode.notes
    assert_equal Date.yesterday, episode.air_date
    
    file.close
    file.unlink
  end
  
  test "should handle invalid CSV" do
    file = Tempfile.new(['invalid', '.csv'])
    file.write("This is not a valid CSV")
    file.rewind
    
    post import_admin_episodes_path, params: { 
      file: fixture_file_upload(file.path, 'text/csv'), 
      update_existing: "1" 
    }
    
    assert_redirected_to admin_episodes_path
    assert_not_nil flash[:alert]
    
    file.close
    file.unlink
  end

  # Test for YouTube Summarization
  test "should enqueue summarization job and update summary" do
    sign_in_as_admin # Assumes this helper method exists from test_helper.rb

    # Use ActiveJob test adapter for inline execution
    ActiveJob::Base.queue_adapter = :test

    # Create an episode with a valid video_id
    episode = Episode.create!(
      number: 101,
      title: "Test Summarization Episode",
      video_id: "dQw4w9WgXcQ", # Valid ID for youtube_url generation
      air_date: Date.today
    )

    # Mock the summarization service
    mock_summary = "This is a mocked summary of the video."
    mock_service = Minitest::Mock.new
    mock_service.expect :call, mock_summary # Expect 'call' to be called and return the mock summary

    mock_summary = "This is a mocked summary of the video."

    # Stub the 'call' method on any instance of the service
    YoutubeSummarizerService.any_instance.stubs(:call).returns(mock_summary)

    # Assert job is enqueued when action is posted
    assert_enqueued_with(job: SummarizeYoutubeVideoJob, args: [episode.id]) do
      post summarize_admin_episode_url(episode)
    end

    # Assert redirection and flash notice after enqueuing
    assert_redirected_to admin_episode_url(episode)
    assert_equal "Summarization job queued for Episode ##{episode.number}.", flash[:notice]

    # Perform the job inline
    perform_enqueued_jobs

    # Reload the episode and check if the summary was updated
    episode.reload
    assert_equal mock_summary, episode.summary
  end

  test "should show alert if episode has no youtube_url for summarization" do
    sign_in_as_admin

    # Create an episode likely to have no youtube_url (e.g., placeholder ID)
    episode = Episode.create!(
      number: 102,
      title: "Episode without valid video",
      video_id: "EPISODE_PLACEHOLDER",
      air_date: Date.today
    )

    # Ensure no job is enqueued
    assert_no_enqueued_jobs do
      post summarize_admin_episode_url(episode)
    end

    # Assert redirection and flash alert
    assert_redirected_to admin_episode_url(episode)
    assert_equal "Cannot summarize: Episode ##{episode.number} has no valid YouTube URL.", flash[:alert]

    # Ensure summary remains nil/blank
    episode.reload
    assert_nil episode.summary
  end
end
