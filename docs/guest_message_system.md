# Guest Message System Documentation

## Overview

The Guest Message System allows website visitors to send messages to podcast guests through their profile pages or as general inquiries. Messages are stored in the database and can be managed by administrators. The system includes features for tracking message status, forwarding messages to guests, and adding admin notes.

## Features

- **Contact Forms**: Embedded on profile pages and general contact page
- **Message Tracking**: System tracks message status (new, read, forwarded, replied, archived)
- **Admin Interface**: Full CRUD capabilities for managing messages
- **Email Notifications**: Sends confirmation to sender and notification to admin
- **Message Forwarding**: Option to forward messages to guests (currently disabled)
- **Guest Preferences**: Guests can opt-in/out of message forwarding
- **Filtering**: Admin can filter messages by status and recipient

## Components

### Models

- **GuestMessage**: Main model that stores message data
  - Belongs to Profile (optional - can be a general inquiry)
  - Status constants: new, read, forwarded, replied, archived
  - Methods for status management and guest information

- **Profile**: Extended with message preferences
  - Has many guest_messages
  - New fields: allow_messages, auto_forward_messages, message_forwarding_email

### Controllers

- **GuestMessagesController**: Handles public message submission
  - Creates new messages
  - Sends confirmation and notification emails
  
- **Admin::GuestMessagesController**: Admin management interface
  - Full CRUD operations
  - Message forwarding capability
  - Status updating

### Views

- **Contact Form Modal**: Embedded in profile show page
  - Form for submitting messages to specific guests
  
- **Admin Views**:
  - Index with filtering by status and guest
  - Show page with message details
  - Edit form for admin notes and status
  
### Mailers

- **GuestMessageMailer**: Handles all email communications
  - sender_confirmation: Confirms receipt to sender
  - admin_notification: Notifies admin of new messages
  - forward_to_guest: Forwards message to guest (currently disabled)

## Configuration

The system uses application-wide configuration variables set in `config/application.rb`:

```ruby
config.podcast_email = "podcast@example.com"
config.podcast_admin_email = "admin@example.com"
```

## Message Flow

1. User submits message via contact form
2. System creates GuestMessage record with "new" status
3. Confirmation email is sent to user
4. Notification email is sent to administrator
5. Admin can view and manage messages through admin interface
6. *(Disabled)* If auto-forwarding is enabled for guest, message is forwarded automatically
7. *(Disabled)* Admin can manually forward messages

## Current Status

- Basic messaging functionality is complete
- Email forwarding is currently disabled but code is in place
- Admin interface is fully functional
- Status tracking is functional
- System is fully tested with unit, functional, and integration tests

## Future Enhancements

- Re-enable email forwarding to guests when ready
- Add message analytics
- Enhanced filtering options for admin
- Message reply tracking

## Testing

The system includes comprehensive tests:

- Model tests for GuestMessage
- Controller tests for GuestMessagesController
- Controller tests for Admin::GuestMessagesController
- Mailer tests for GuestMessageMailer
- System tests for end-to-end functionality

To run all tests:

```bash
bin/rails test
bin/rails test:system
```

## Security Considerations

- Email addresses are never displayed publicly
- Admin authentication required for message management
- Input validation on all form fields
- Messages marked as forwarded but not actually sent (currently)

## Troubleshooting

If emails are not being sent:
1. Check email configuration in development.rb/production.rb
2. Verify podcast_email and podcast_admin_email are set
3. Check mailer templates for proper content