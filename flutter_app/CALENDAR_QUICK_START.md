# Calendar Quick Start Guide

## Installation

```bash
cd flutter_app
flutter pub get
flutter run
```

## Usage

### Navigate to Calendar
From home screen → Tap calendar icon in AppBar

### Create Event
1. Calendar view → Tap FAB (+)
2. Fill form:
   - Title (required)
   - Date/Time
   - Category
   - Attendees
3. Tap "Create"

### View Event
- Month view: Tap date → Bottom sheet
- Week view: Tap event card
- Day view: Tap event block

### Edit Event
1. Event detail screen → Tap edit icon
2. Modify fields
3. Tap "Save"

### Delete Event
1. Event detail screen → Tap delete icon
2. Confirm deletion

## Routes

```dart
Navigator.pushNamed(context, '/calendar');              // Month view
Navigator.pushNamed(context, '/calendar/week');         // Week view
Navigator.pushNamed(context, '/calendar/day', arguments: date);
Navigator.pushNamed(context, '/calendar/event/create', arguments: date);
Navigator.pushNamed(context, '/calendar/event/:id');
```

## Code Examples

### Access Calendar State
```dart
class MyWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final calendarState = ref.watch(calendarProvider);
    final events = calendarState.events;

    return ListView.builder(
      itemCount: events.length,
      itemBuilder: (context, index) {
        return EventCard(event: events[index]);
      },
    );
  }
}
```

### Create Event
```dart
final event = CalendarEvent(
  id: '',
  familyId: 'family123',
  title: 'Soccer Practice',
  startTime: DateTime.now(),
  endTime: DateTime.now().add(Duration(hours: 1)),
  attendees: ['user1', 'user2'],
  category: 'sport',
  updatedAt: DateTime.now().toUtc(),
  lastModifiedBy: 'user1',
);

await ref.read(calendarProvider.notifier).createEvent(event);
```

### Get Events for Date
```dart
final events = ref.read(calendarProvider.notifier)
  .getEventsForDate(DateTime(2025, 11, 15));
```

### Check Permissions
```dart
final user = await LocalStorage.instance.getCurrentUser();
final isParent = user?['role'] == 'parent';

if (isParent) {
  // Show edit/delete buttons
}
```

## Troubleshooting

### Events Not Loading
```bash
# Check LocalStorage initialized
await LocalStorage.instance.init();

# Verify events in Hive
flutter pub run hive show events
```

### Sync Not Working
```bash
# Check queue
final queueSize = SyncQueue.instance.getQueueSize();
print('Queue size: $queueSize');

# Trigger manual sync
await SyncQueue.instance.performSync();
```

### UI Not Updating
```dart
// Ensure ProviderScope wraps app
runApp(ProviderScope(child: App()));

// Use ref.watch in widgets
final state = ref.watch(calendarProvider);
```

## Key Files

- **State:** `lib/features/calendar/calendar_provider.dart`
- **Month View:** `lib/features/calendar/calendar_month_view.dart`
- **Event Card:** `lib/widgets/event_card.dart`
- **Event Form:** `lib/features/calendar/event_form_screen.dart`
- **Routes:** `lib/main.dart`

## Testing

```bash
# Run all tests
flutter test

# Test calendar feature
flutter test test/features/calendar/

# Integration test
flutter drive --target=test_driver/app.dart
```

## Performance

- Events cached in Hive (instant load)
- Background sync (non-blocking)
- Lazy loading (only visible range)
- 60fps scrolling

## Support

- Documentation: `docs/calendar_implementation.md`
- Summary: `CALENDAR_SUMMARY.md`
- Issues: Create ticket with screenshots
