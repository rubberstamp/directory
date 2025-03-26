require "test_helper"

class GuestMessageTest < ActiveSupport::TestCase
  test "should create a valid guest message" do
    profile = Profile.create!(
      name: "Guest Message Test", 
      email: "guest_message_test@example.com"
    )
    
    message = GuestMessage.new(
      sender_name: "Test Sender",
      sender_email: "test@example.com",
      subject: "Test Subject",
      message: "This is a test message",
      profile: profile,
      status: GuestMessage::STATUSES[:new]
    )
    assert message.valid?
  end

  test "should not save guest message without sender email" do
    message = GuestMessage.new(
      sender_name: "Test Sender",
      message: "This is a test message"
    )
    assert_not message.valid?
    assert_includes message.errors[:sender_email], "can't be blank"
  end

  test "should not save guest message with invalid sender email" do
    message = GuestMessage.new(
      sender_name: "Test Sender",
      sender_email: "invalid-email",
      message: "This is a test message"
    )
    assert_not message.valid?
    assert_includes message.errors[:sender_email], "is invalid"
  end

  test "should not save guest message without message content" do
    message = GuestMessage.new(
      sender_name: "Test Sender",
      sender_email: "test@example.com"
    )
    assert_not message.valid?
    assert_includes message.errors[:message], "can't be blank"
  end

  test "profile association is optional" do
    message = GuestMessage.new(
      sender_name: "Test Sender",
      sender_email: "test@example.com",
      subject: "Test Subject",
      message: "This is a test message",
      status: GuestMessage::STATUSES[:new]
    )
    assert message.valid?
  end

  test "should return correct guest name" do
    profile = profiles(:one)
    message_with_profile = GuestMessage.new(
      sender_name: "Test Sender",
      sender_email: "test@example.com",
      message: "This is a test message",
      profile: profile
    )
    assert_equal profile.name, message_with_profile.guest_name

    message_without_profile = GuestMessage.new(
      sender_name: "Test Sender",
      sender_email: "test@example.com",
      message: "This is a test message"
    )
    assert_equal "General Inquiry", message_without_profile.guest_name
  end

  test "should mark message as read" do
    message = GuestMessage.new(
      sender_name: "Test Sender",
      sender_email: "test@example.com",
      message: "This is a test message",
      status: GuestMessage::STATUSES[:new]
    )
    message.mark_as_read!
    assert_equal GuestMessage::STATUSES[:read], message.status
  end

  test "should mark message as forwarded" do
    message = GuestMessage.new(
      sender_name: "Test Sender",
      sender_email: "test@example.com",
      message: "This is a test message",
      status: GuestMessage::STATUSES[:read]
    )
    message.mark_as_forwarded!
    assert_equal GuestMessage::STATUSES[:forwarded], message.status
    assert_not_nil message.forwarded_at
  end

  test "can_be_forwarded? returns true when profile allows messages and has forwarding email" do
    profile = profiles(:one)
    profile.update(allow_messages: true, message_forwarding_email: "guest@example.com")
    
    message = GuestMessage.new(
      sender_name: "Test Sender",
      sender_email: "test@example.com",
      message: "This is a test message",
      profile: profile
    )
    
    assert message.can_be_forwarded?
  end

  test "can_be_forwarded? returns false when profile disallows messages" do
    profile = profiles(:one)
    profile.update(allow_messages: false, message_forwarding_email: "guest@example.com")
    
    message = GuestMessage.new(
      sender_name: "Test Sender",
      sender_email: "test@example.com",
      message: "This is a test message",
      profile: profile
    )
    
    assert_not message.can_be_forwarded?
  end

  test "can_be_forwarded? returns false when profile has no forwarding email" do
    profile = profiles(:one)
    profile.update(allow_messages: true, message_forwarding_email: nil)
    
    message = GuestMessage.new(
      sender_name: "Test Sender",
      sender_email: "test@example.com",
      message: "This is a test message",
      profile: profile
    )
    
    assert_not message.can_be_forwarded?
  end

  test "can_be_forwarded? returns false when message has no profile" do
    message = GuestMessage.new(
      sender_name: "Test Sender",
      sender_email: "test@example.com",
      message: "This is a test message"
    )
    
    assert_not message.can_be_forwarded?
  end

  test "forward_manually returns true when message can be forwarded" do
    profile = profiles(:one)
    profile.update(allow_messages: true, message_forwarding_email: "guest@example.com")
    
    message = GuestMessage.new(
      sender_name: "Test Sender",
      sender_email: "test@example.com",
      message: "This is a test message",
      profile: profile
    )
    
    assert message.forward_manually
  end

  test "forward_manually returns false when message cannot be forwarded" do
    profile = profiles(:one)
    profile.update(allow_messages: false)
    
    message = GuestMessage.new(
      sender_name: "Test Sender",
      sender_email: "test@example.com",
      message: "This is a test message",
      profile: profile
    )
    
    assert_not message.forward_manually
  end

  test "scopes filter messages correctly" do
    GuestMessage.delete_all
    
    profile = profiles(:one)
    
    new_message = GuestMessage.create!(
      sender_name: "New Sender",
      sender_email: "new@example.com",
      message: "New message",
      status: GuestMessage::STATUSES[:new],
      profile: profile
    )
    
    read_message = GuestMessage.create!(
      sender_name: "Read Sender",
      sender_email: "read@example.com",
      message: "Read message",
      status: GuestMessage::STATUSES[:read],
      profile: profile
    )
    
    forwarded_message = GuestMessage.create!(
      sender_name: "Forwarded Sender",
      sender_email: "forwarded@example.com",
      message: "Forwarded message",
      status: GuestMessage::STATUSES[:forwarded]
    )
    
    assert_includes GuestMessage.new_messages, new_message
    assert_not_includes GuestMessage.new_messages, read_message
    assert_not_includes GuestMessage.new_messages, forwarded_message
    
    assert_includes GuestMessage.read_messages, read_message
    assert_not_includes GuestMessage.read_messages, new_message
    assert_not_includes GuestMessage.read_messages, forwarded_message
    
    assert_includes GuestMessage.forwarded_messages, forwarded_message
    assert_not_includes GuestMessage.forwarded_messages, new_message
    assert_not_includes GuestMessage.forwarded_messages, read_message
    
    assert_includes GuestMessage.for_guest(profile.id), new_message
    assert_includes GuestMessage.for_guest(profile.id), read_message
    assert_not_includes GuestMessage.for_guest(profile.id), forwarded_message
    
    assert_includes GuestMessage.general_inquiries, forwarded_message
    assert_not_includes GuestMessage.general_inquiries, new_message
    assert_not_includes GuestMessage.general_inquiries, read_message
  end
end
