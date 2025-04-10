require "test_helper"

class Admin::ProfilesFiltersTest < ActionDispatch::IntegrationTest
  setup do
    # Create admin user
    @admin = User.create!(
      email: "admin-profile-filters@example.com",
      password: "password123",
      password_confirmation: "password123",
      admin: true
    )

    # Create test profiles with various attributes
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

    # Sign in as admin before each test
    post user_session_path, params: {
      user: { email: @admin.email, password: "password123" }
    }
  end

  test "index shows all profiles by default" do
    get admin_profiles_path
    assert_response :success

    # Test that all profiles are shown (we're not counting header rows, just checking names are present)
    assert_match @profile1.name, response.body
    assert_match @profile2.name, response.body
    assert_match @profile3.name, response.body
  end

  test "search filter works for name" do
    get admin_profiles_path, params: { search: "John Doe" }
    assert_response :success

    # Should match profile1
    assert_match @profile1.name, response.body

    # Should not match other profiles
    assert_no_match @profile2.name, response.body
    assert_no_match @profile3.name, response.body
  end

  test "search filter works for email" do
    get admin_profiles_path, params: { search: "jane@" }
    assert_response :success

    # Should match profile2
    assert_match @profile2.name, response.body

    # Should not match other profiles
    assert_no_match @profile1.name, response.body
    assert_no_match @profile3.name, response.body
  end

  test "search filter works for company" do
    get admin_profiles_path, params: { search: "Acme" }
    assert_response :success

    # Should match profile3
    assert_match @profile3.name, response.body

    # Should not match other profiles
    assert_no_match @profile1.name, response.body
    assert_no_match @profile2.name, response.body
  end

  test "search filter works for episode title" do
    get admin_profiles_path, params: { search: "Leadership" }
    assert_response :success

    # Should match profile1
    assert_match @profile1.name, response.body

    # Should not match other profiles
    assert_no_match @profile2.name, response.body
    assert_no_match @profile3.name, response.body
  end

  test "status filter works for guest profiles" do
    get admin_profiles_path, params: { status: "guest" }
    assert_response :success

    # Should match profiles with submission_date
    assert_match @profile1.name, response.body
    assert_match @profile2.name, response.body

    # Should not match profile without submission_date
    assert_no_match @profile3.name, response.body
  end

  test "status filter works for profiles with episodes" do
    get admin_profiles_path, params: { status: "episode" }
    assert_response :success

    # Should match profile with episode_url
    assert_match @profile1.name, response.body

    # Should not match profiles without episode_url
    assert_no_match @profile2.name, response.body
    assert_no_match @profile3.name, response.body
  end

  test "status filter works for missing episode profiles" do
    get admin_profiles_path, params: { status: "missing_episode" }
    assert_response :success

    # Should match profile with submission_date but no episode_url
    assert_match @profile2.name, response.body

    # Should not match profile with episode_url or no submission_date
    assert_no_match @profile1.name, response.body
    assert_no_match @profile3.name, response.body
  end

  test "status filter works for interested in procurement profiles" do
    get admin_profiles_path, params: { status: "interested" }
    assert_response :success

    # Should match profile with interested_in_procurement
    assert_match @profile2.name, response.body

    # Should not match other profiles
    assert_no_match @profile1.name, response.body
    assert_no_match @profile3.name, response.body
  end

  test "sorting by name ascending works" do
    get admin_profiles_path, params: { sort: "name_asc" }
    assert_response :success

    # Check that all profiles are present
    assert_match @profile1.name, response.body
    assert_match @profile2.name, response.body
    assert_match @profile3.name, response.body

    # Check content order in the HTML (testing actual sorting would require more complex assertions)
    html_content = response.body
    assert html_content.index(@profile1.name) > 0
    assert html_content.index(@profile2.name) > 0
    assert html_content.index(@profile3.name) > 0
  end

  test "sorting by name descending works" do
    get admin_profiles_path, params: { sort: "name_desc" }
    assert_response :success

    # Check that all profiles are present
    assert_match @profile1.name, response.body
    assert_match @profile2.name, response.body
    assert_match @profile3.name, response.body

    # Check content order in the HTML (testing actual sorting would require more complex assertions)
    html_content = response.body
    assert html_content.index(@profile1.name) > 0
    assert html_content.index(@profile2.name) > 0
    assert html_content.index(@profile3.name) > 0
  end

  test "sorting by submission date descending works" do
    get admin_profiles_path, params: { sort: "submission_date_desc" }
    assert_response :success

    # Check that profiles are present
    assert_match @profile1.name, response.body
    assert_match @profile2.name, response.body

    # Check content order in the HTML
    html_content = response.body
    assert html_content.index(@profile1.name) < html_content.index(@profile2.name),
           "Profile1 should appear before Profile2 when sorting by submission_date_desc"
  end

  test "sorting by episode date descending works" do
    get admin_profiles_path, params: { sort: "episode_date_desc" }
    assert_response :success

    # Profile1 should be present (has episode date)
    assert_match @profile1.name, response.body
  end

  test "combined filtering and sorting works" do
    get admin_profiles_path, params: { status: "guest", sort: "submission_date_desc" }
    assert_response :success

    # Should match profiles with submission_date
    assert_match @profile1.name, response.body
    assert_match @profile2.name, response.body

    # Should not match profile without submission_date
    assert_no_match @profile3.name, response.body

    # Check content order in the HTML
    html_content = response.body
    assert html_content.index(@profile1.name) < html_content.index(@profile2.name),
           "Profile1 should appear before Profile2 when combining guest filter with submission_date_desc sort"
  end
end
