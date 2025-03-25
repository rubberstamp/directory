require "test_helper"

class Admin::SpecializationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    # Create admin user
    @admin = User.create!(
      email: "admin-specializations@example.com", 
      password: 'password123', 
      password_confirmation: 'password123',
      admin: true
    )
    
    # Create test specialization
    @specialization = Specialization.create!(
      name: "Test Specialization",
      description: "Test specialization description"
    )
  end
  
  test "should get index" do
    # Sign in as admin
    post user_session_path, params: { 
      user: { email: @admin.email, password: 'password123' } 
    }
    
    # Access specializations index
    get admin_specializations_url
    assert_response :success
  end
  
  test "should get new" do
    # Sign in as admin
    post user_session_path, params: { 
      user: { email: @admin.email, password: 'password123' } 
    }
    
    # Access new specialization form
    get new_admin_specialization_url
    assert_response :success
  end
  
  test "should create specialization" do
    # Sign in as admin
    post user_session_path, params: { 
      user: { email: @admin.email, password: 'password123' } 
    }
    
    # Test specialization count change
    assert_difference('Specialization.count') do
      post admin_specializations_url, params: {
        specialization: {
          name: "New Specialization",
          description: "New specialization description"
        }
      }
    end
    
    # Check redirect to specializations index
    assert_redirected_to admin_specializations_url
  end
  
  test "should show specialization" do
    # Sign in as admin
    post user_session_path, params: { 
      user: { email: @admin.email, password: 'password123' } 
    }
    
    # View specialization
    get admin_specialization_url(@specialization)
    assert_response :success
  end
  
  test "should get edit" do
    # Sign in as admin
    post user_session_path, params: { 
      user: { email: @admin.email, password: 'password123' } 
    }
    
    # Access edit form
    get edit_admin_specialization_url(@specialization)
    assert_response :success
  end
  
  test "should update specialization" do
    # Sign in as admin
    post user_session_path, params: { 
      user: { email: @admin.email, password: 'password123' } 
    }
    
    # Update specialization
    patch admin_specialization_url(@specialization), params: {
      specialization: {
        name: "Updated Specialization",
        description: "Updated description"
      }
    }
    
    # Check redirect and updated values
    assert_redirected_to admin_specializations_url
    @specialization.reload
    assert_equal "Updated Specialization", @specialization.name
    assert_equal "Updated description", @specialization.description
  end
  
  test "should destroy specialization" do
    # Sign in as admin
    post user_session_path, params: { 
      user: { email: @admin.email, password: 'password123' } 
    }
    
    # Test specialization count change on delete
    assert_difference('Specialization.count', -1) do
      delete admin_specialization_url(@specialization)
    end
    
    # Check redirect
    assert_redirected_to admin_specializations_url
  end
  
  test "should not allow non-admin access" do
    # Create regular user
    regular_user = User.create!(
      email: "user-specializations@example.com", 
      password: 'password123', 
      password_confirmation: 'password123',
      admin: false
    )
    
    # Sign in as regular user
    post user_session_path, params: { 
      user: { email: regular_user.email, password: 'password123' } 
    }
    
    # Try accessing admin specializations
    get admin_specializations_url
    assert_redirected_to root_path
  end
end