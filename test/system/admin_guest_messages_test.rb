require "application_system_test_case"

class AdminGuestMessagesTest < ApplicationSystemTestCase
  setup do
    @admin = users(:admin)
    @profile = profiles(:one)
    
    # Create some test messages with different statuses
    @new_message = GuestMessage.create!(
      sender_name: "New Sender",
      sender_email: "new@example.com",
      subject: "New Message",
      message: "This is a new message",
      profile: @profile,
      status: GuestMessage::STATUSES[:new]
    )
    
    @read_message = GuestMessage.create!(
      sender_name: "Read Sender",
      sender_email: "read@example.com",
      subject: "Read Message",
      message: "This is a read message",
      profile: @profile,
      status: GuestMessage::STATUSES[:read]
    )
    
    @forwarded_message = GuestMessage.create!(
      sender_name: "Forwarded Sender",
      sender_email: "forwarded@example.com",
      subject: "Forwarded Message",
      message: "This is a forwarded message",
      profile: @profile,
      status: GuestMessage::STATUSES[:forwarded],
      forwarded_at: 1.day.ago
    )
    
    login_as(@admin)
  end
  
  test "visiting the index" do
    visit admin_guest_messages_url
    
    assert_selector "h1", text: "Guest Messages"
    assert_selector "table tbody tr", count: 3
    
    # Check that the messages are displayed correctly
    assert_text @new_message.sender_name
    assert_text @read_message.sender_name
    assert_text @forwarded_message.sender_name
  end
  
  test "filtering messages by status" do
    visit admin_guest_messages_url
    
    # Filter by new status
    select "New", from: "status"
    click_on "Filter"
    
    assert_selector "table tbody tr", count: 1
    assert_text @new_message.sender_name
    assert_no_text @read_message.sender_name
    assert_no_text @forwarded_message.sender_name
    
    # Filter by read status
    select "Read", from: "status"
    click_on "Filter"
    
    assert_selector "table tbody tr", count: 1
    assert_no_text @new_message.sender_name
    assert_text @read_message.sender_name
    assert_no_text @forwarded_message.sender_name
  end
  
  test "viewing a message" do
    visit admin_guest_messages_url
    
    # Click on the view link for the new message
    within "table tbody tr", text: @new_message.sender_name do
      click_on "View"
    end
    
    assert_selector "h1", text: "Guest Message Details"
    assert_text @new_message.sender_name
    assert_text @new_message.sender_email
    assert_text @new_message.subject
    assert_text @new_message.message
    
    # Verify that the status is correctly displayed
    assert_selector "span", text: "New"
    
    # When viewing a new message, it should be automatically marked as read
    @new_message.reload
    assert_equal GuestMessage::STATUSES[:read], @new_message.status
  end
  
  test "editing a message" do
    visit admin_guest_message_url(@read_message)
    click_on "Edit"
    
    assert_selector "h1", text: "Edit Guest Message"
    
    # Add admin notes and change status
    fill_in "Admin notes", with: "These are test admin notes"
    select "Archived", from: "Status"
    click_on "Update Message"
    
    assert_text "Guest message was successfully updated"
    
    # Verify changes
    assert_text "Archived"
    assert_text "These are test admin notes"
    
    @read_message.reload
    assert_equal "archived", @read_message.status
    assert_equal "These are test admin notes", @read_message.admin_notes
  end
  
  test "forwarding a message" do
    # Update profile to allow messages
    @profile.update(
      allow_messages: true, 
      message_forwarding_email: "guest@example.com"
    )
    
    visit admin_guest_message_url(@new_message)
    
    assert_selector "button", text: "Forward to Guest"
    click_on "Forward to Guest"
    
    assert_text "Message has been forwarded to the guest"
    
    # Verify that the message was marked as forwarded
    @new_message.reload
    assert_equal GuestMessage::STATUSES[:forwarded], @new_message.status
    assert_not_nil @new_message.forwarded_at
  end
  
  test "cannot forward a message when guest disallows messages" do
    # Update profile to disallow messages
    @profile.update(
      allow_messages: false, 
      message_forwarding_email: "guest@example.com"
    )
    
    visit admin_guest_message_url(@new_message)
    
    assert_selector "button", text: "Forward to Guest"
    click_on "Forward to Guest"
    
    assert_text "Unable to forward message. Guest has disabled messages or has no forwarding email."
    
    # Verify that the message was not forwarded
    @new_message.reload
    assert_equal GuestMessage::STATUSES[:new], @new_message.status
    assert_nil @new_message.forwarded_at
  end
  
  test "deleting a message" do
    visit admin_guest_message_url(@read_message)
    
    accept_confirm do
      click_on "Delete"
    end
    
    assert_text "Guest message was successfully deleted"
    assert_current_path admin_guest_messages_path
    
    # Verify that the message was deleted
    assert_no_text @read_message.subject
  end
  
  test "dashboard shows correct message counts" do
    visit admin_dashboard_url
    
    assert_selector "h3", text: "1" # Should show 1 new message
    assert_selector "p", text: "New Messages / 3 Total"
    
    # Click on the "View New Messages" link
    click_on "View New Messages"
    
    assert_current_path admin_guest_messages_path(status: 'new')
    assert_selector "table tbody tr", count: 1
    assert_text @new_message.sender_name
  end
end