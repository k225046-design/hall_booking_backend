# Hall Management System - Messages Feature Implementation

## Approved Plan Summary
- Add FCM-triggered popup (Snackbar style) for new messages
- Create MessagesScreen widget showing all messages (global + per booking)
- Update NotificationService with reactive stream
- Integrate into dashboards with badges

## Implementation Steps (Step-by-step)

### Step 1: Create Supporting Models [PENDING]
- ✅ Create `hall_booking_app/lib/message_model.dart`
  - Define `Message` class (id, text, sender, timestamp, bookingId, isRead)

### Step 2: Enhance NotificationService [PENDING]
- ✅ Update `hall_booking_app/lib/notification_service.dart`
  - Add `StreamController<List<Message>> messagesStream`
  - Enhance `onMessage` to parse FCM → emit to stream
  - Add `fetchAllMessages(int userId)` API method
  - Add `markAsRead(int messageId)`

### Step 3: Create Messages UI [PENDING]
- ✅ Create `hall_booking_app/lib/messages_screen.dart`
  - ListView of messages, grouped by booking/hall
  - Search/filter, unread count, FAB compose
  - StreamBuilder for real-time updates

### Step 4: Add Popup & Integration [PENDING]
- ✅ Update `Hall management system/hall_booking_app/lib/main.dart`
  - Global `NavigatorKey` for overlays
  - Wrap MaterialApp with `StreamBuilder(messagesStream)` → Snackbar popup
  - Add Messages badge/icon to CustomerDashboard/AdminDashboard AppBars
  - Route: `/messages` → MessagesScreen

### Step 5: Testing & Polish [PENDING]
- Test FCM popup → navigation
- Test real-time updates
- Add unread badges
- `flutter pub get` if needed
- Hot restart app

## Progress
- ✅ Step 1 Complete
- ✅ Step 2 Complete
- [ ] Step 3 Complete
- [ ] Step 4 Complete
- [ ] Step 5 Complete

**Steps 1-3 ✅ Complete** (message_model.dart, notification_service.dart enhanced with stream/FCM, messages_screen.dart with real-time UI).

