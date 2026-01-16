# frozen_string_literal: true

require "test_helper"

class GenerateGuestBioJobTest < ActiveJob::TestCase
  setup do
    @profile = Profile.create!(
      name: "Test Bio Profile",
      email: "test-bio-job-#{SecureRandom.hex(4)}@example.com",
      bio: nil
    )
    @profile.skip_geocoding = true
    @profile.save!
  end

  test "updates profile bio on successful generation" do
    mock_service = mock("bio_generator_service")
    mock_service.expects(:call).returns("Generated bio for #{@profile.name} based on podcast appearances.")

    GuestBioGeneratorService.stubs(:new).returns(mock_service)

    GenerateGuestBioJob.perform_now(@profile.id)

    @profile.reload
    assert_equal "Generated bio for #{@profile.name} based on podcast appearances.", @profile.bio
  end

  test "handles missing profile gracefully" do
    assert_nothing_raised do
      GenerateGuestBioJob.perform_now(999999)
    end
  end

  test "skips profiles that already have bios" do
    @profile.update!(bio: "Existing bio content")

    # Service should never be instantiated for profiles with existing bios
    GuestBioGeneratorService.expects(:new).never

    GenerateGuestBioJob.perform_now(@profile.id)

    @profile.reload
    assert_equal "Existing bio content", @profile.bio
  end

  test "handles nil bio from service" do
    mock_service = mock("bio_generator_service")
    mock_service.expects(:call).returns(nil)

    GuestBioGeneratorService.stubs(:new).returns(mock_service)

    GenerateGuestBioJob.perform_now(@profile.id)

    @profile.reload
    assert_nil @profile.bio
  end

  test "handles BioGenerationError gracefully without updating profile" do
    mock_service = mock("bio_generator_service")
    mock_service.expects(:call).raises(GuestBioGeneratorService::BioGenerationError, "API quota exceeded")

    GuestBioGeneratorService.stubs(:new).returns(mock_service)

    assert_nothing_raised do
      GenerateGuestBioJob.perform_now(@profile.id)
    end

    @profile.reload
    # Bio should remain nil since error occurred
    assert_nil @profile.bio
  end

  test "handles unexpected errors gracefully" do
    mock_service = mock("bio_generator_service")
    mock_service.expects(:call).raises(StandardError, "Unexpected error")

    GuestBioGeneratorService.stubs(:new).returns(mock_service)

    assert_nothing_raised do
      GenerateGuestBioJob.perform_now(@profile.id)
    end

    @profile.reload
    # Bio should remain nil since error occurred
    assert_nil @profile.bio
  end
end
