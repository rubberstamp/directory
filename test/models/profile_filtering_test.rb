require "test_helper"

class ProfileFilteringTest < ActiveSupport::TestCase
  setup do
    # Remove any existing profiles to avoid test interference
    Profile.delete_all
    
    # Create test profiles with various attributes for filtering tests
    @profile1 = Profile.create!(
      name: "John Doe",
      email: "john@example.com",
      company: "ABC Corp",
      headline: "CEO at ABC Corp",
      submission_date: 1.month.ago,
      deprecated_episode_title: "Leadership in Procurement",
      deprecated_episode_url: "abc123",
      deprecated_episode_date: 20.days.ago
    )
    
    @profile2 = Profile.create!(
      name: "Jane Smith",
      email: "jane@example.com",
      company: "XYZ Industries",
      headline: "Procurement Director",
      submission_date: 2.months.ago,
      deprecated_episode_title: nil,
      deprecated_episode_url: nil,
      deprecated_episode_date: nil,
      interested_in_procurement: true
    )
    
    @profile3 = Profile.create!(
      name: "Robert Johnson",
      email: "robert@example.com",
      company: "Acme Inc",
      headline: "Supply Chain Manager",
      submission_date: nil,
      deprecated_episode_title: nil,
      deprecated_episode_url: nil,
      deprecated_episode_date: nil
    )
  end
  
  # Helper method to apply filters similar to the controller
  def apply_filters(search: nil, status: nil, sort: nil)
    # Start with all profiles
    case sort
    when 'name_asc'
      profiles = Profile.order(name: :asc)
    when 'name_desc'
      profiles = Profile.order(name: :desc)
    when 'submission_date_desc'
      profiles = Profile.order(submission_date: :desc)
    when 'submission_date_asc'
      profiles = Profile.order(submission_date: :asc)
    when 'episode_date_desc'
      profiles = Profile.order(deprecated_episode_date: :desc)
    when 'episode_date_asc'
      profiles = Profile.order(deprecated_episode_date: :asc)
    else
      profiles = Profile.order(created_at: :desc)
    end
    
    # Apply search filters if provided
    if search.present?
      search_term = "%#{search.downcase}%"
      profiles = profiles.where(
        "LOWER(name) LIKE ? OR LOWER(email) LIKE ? OR LOWER(company) LIKE ? OR LOWER(deprecated_episode_title) LIKE ?", 
        search_term, search_term, search_term, search_term
      )
    end
    
    # Apply status filter if provided
    if status.present?
      case status
      when 'guest'
        profiles = profiles.where.not(submission_date: nil)
      when 'episode'
        profiles = profiles.where.not(deprecated_episode_url: nil)
      when 'missing_episode'
        profiles = profiles.where.not(submission_date: nil).where(deprecated_episode_url: nil)
      when 'interested'
        profiles = profiles.where(interested_in_procurement: true)
      end
    end
    
    profiles
  end
  
  test "should find all profiles with no filters" do
    profiles = apply_filters
    assert_equal 3, profiles.count
    assert_includes profiles, @profile1
    assert_includes profiles, @profile2
    assert_includes profiles, @profile3
  end
  
  test "should filter by name search" do
    profiles = apply_filters(search: "John Doe")
    assert_equal 1, profiles.count
    assert_includes profiles, @profile1
    assert_not_includes profiles, @profile2
    assert_not_includes profiles, @profile3
  end
  
  test "should filter by email search" do
    profiles = apply_filters(search: "jane@")
    assert_equal 1, profiles.count
    assert_includes profiles, @profile2
  end
  
  test "should filter by company search" do
    profiles = apply_filters(search: "acme")
    assert_equal 1, profiles.count
    assert_includes profiles, @profile3
  end
  
  test "should filter by episode title search" do
    profiles = apply_filters(search: "leadership")
    assert_equal 1, profiles.count
    assert_includes profiles, @profile1
  end
  
  test "should filter by guest status" do
    profiles = apply_filters(status: "guest")
    assert_equal 2, profiles.count
    assert_includes profiles, @profile1
    assert_includes profiles, @profile2
    assert_not_includes profiles, @profile3
  end
  
  test "should filter by episode status" do
    profiles = apply_filters(status: "episode")
    assert_equal 1, profiles.count
    assert_includes profiles, @profile1
  end
  
  test "should filter by missing episode status" do
    profiles = apply_filters(status: "missing_episode")
    assert_equal 1, profiles.count
    assert_includes profiles, @profile2
  end
  
  test "should filter by interested in procurement status" do
    profiles = apply_filters(status: "interested")
    assert_equal 1, profiles.count
    assert_includes profiles, @profile2
  end
  
  test "should sort by name ascending" do
    profiles = apply_filters(sort: "name_asc").to_a
    assert_equal [@profile2, @profile1, @profile3].sort_by(&:name), profiles
  end
  
  test "should sort by name descending" do
    profiles = apply_filters(sort: "name_desc").to_a
    assert_equal [@profile2, @profile1, @profile3].sort_by(&:name).reverse, profiles
  end
  
  test "should sort by submission date descending" do
    profiles = apply_filters(sort: "submission_date_desc").to_a
    
    # Only profiles with submission_date should be at the front
    profiles_with_date = [@profile1, @profile2].sort_by(&:submission_date).reverse
    
    # First two should match the sorted profiles with dates
    assert_equal profiles_with_date.first, profiles.first
    assert_equal profiles_with_date.last, profiles.second
  end
  
  test "should sort by submission date ascending" do
    profiles = apply_filters(sort: "submission_date_asc").where.not(submission_date: nil).to_a
    
    # Only profiles with submission_date should be included, oldest first
    profiles_with_date = [@profile1, @profile2].sort_by(&:submission_date)
    
    # The profiles should be in the correct order
    assert_equal profiles_with_date.first, profiles.first
    assert_equal profiles_with_date.last, profiles.last
  end
  
  test "should sort by episode date descending" do
    profiles = apply_filters(sort: "episode_date_desc").to_a
    
    # Only profile1 has an episode date
    assert_equal @profile1, profiles.first
  end
  
  test "should combine search and status filters" do
    # Create another profile with matching search but different status
    @profile4 = Profile.create!(
      name: "John Smith",
      email: "johnsmith@example.com",
      company: "Smith Co",
      submission_date: nil,
      deprecated_episode_title: nil,
      deprecated_episode_url: nil
    )
    
    profiles = apply_filters(search: "john", status: "guest")
    assert_equal 1, profiles.count
    assert_includes profiles, @profile1
    assert_not_includes profiles, @profile4
  end
  
  test "should combine status and sorting" do
    profiles = apply_filters(status: "guest", sort: "submission_date_desc").to_a
    
    # Should only include profiles with submission_date (guest)
    assert_equal 2, profiles.count
    
    # First should be the most recent submission
    assert_equal @profile1, profiles.first
    assert_equal @profile2, profiles.second
  end
  
  test "should combine search, status and sorting" do
    # Add another similar profile
    @profile5 = Profile.create!(
      name: "Johnny Test",
      email: "johnny@example.com",
      submission_date: 3.months.ago,
      deprecated_episode_url: nil
    )
    
    profiles = apply_filters(search: "john", status: "missing_episode", sort: "name_asc").to_a
    
    # Should match profile5 (contains "john", has submission_date but no episode_url)
    assert_equal 1, profiles.count
    assert_includes profiles, @profile5
    
    # Should not include profile1 (has episode_url)
    assert_not_includes profiles, @profile1
  end
end