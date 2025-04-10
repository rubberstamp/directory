require "test_helper"

class Admin::DashboardControllerTest < ActionDispatch::IntegrationTest
  setup do
    # Create admin user
    @admin = User.create!(
      email: "admin-dashboard@example.com",
      password: "password123",
      password_confirmation: "password123",
      admin: true
    )

    # Create regular user (for access control tests)
    @user = User.create!(
      email: "user-dashboard@example.com",
      password: "password123",
      password_confirmation: "password123",
      admin: false
    )
  end

  test "should get index when logged in as admin" do
    # Sign in as admin
    post user_session_path, params: {
      user: { email: @admin.email, password: "password123" }
    }

    # Access dashboard
    get admin_dashboard_index_url
    assert_response :success
  end

  test "should redirect if not logged in" do
    # Try accessing without login
    get admin_dashboard_index_url
    assert_redirected_to new_user_session_path
  end

  test "should redirect if logged in as non-admin" do
    # Sign in as regular user
    post user_session_path, params: {
      user: { email: @user.email, password: "password123" }
    }

    # Try accessing admin dashboard
    get admin_dashboard_index_url
    assert_redirected_to root_path
  end
end
