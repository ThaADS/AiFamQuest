# Task Recurrence UI Implementation Guide

## Overview

The task recurrence system allows users to create recurring tasks with automatic assignment rotation. Built on top of the backend RRULE expansion engine with 4 rotation strategies.

## Architecture

### Models (`lib/models/recurring_task_models.dart`)
- **RecurringTask**: Template for generating occurrences
- **Occurrence**: Individual instance of a recurring task
- **RotationStrategy**: 4 assignment strategies (round-robin, fairness, random, manual)
- **TaskCategory**: 5 categories (cleaning, care, pet, homework, other)
- **RecurrenceFrequency**: Daily, Weekly, Monthly

### Components

#### 1. RRuleBuilder Widget (`lib/widgets/rrule_builder.dart`)
Visual RRULE string builder with live preview.

**Features**:
- Frequency selector (Daily/Weekly/Monthly)
- Interval input (every N days/weeks/months)
- Weekly: Day selector (Mon-Sun checkboxes)
- Monthly: Day of month selector (1-31)
- End condition: Never / After N occurrences / On date
- Human-readable preview

**Usage**:
```dart
RRuleBuilder(
  initialRRule: 'FREQ=WEEKLY;BYDAY=MO,WE,FR',
  onRRuleChanged: (rrule) {
    print('New RRULE: $rrule');
  },
)
```

#### 2. RecurringTaskForm (`lib/features/tasks/recurring_task_form.dart`)
Comprehensive form for creating/editing recurring tasks.

**Fields**:
- Title (required, min 3 chars)
- Description (optional)
- Category (dropdown with icons)
- Recurrence pattern (RRuleBuilder)
- Rotation strategy (radio buttons with descriptions)
- Assignees (multi-select chips)
- Points (slider 5-100)
- Estimated duration (slider 5-120 min)
- Photo required (switch)
- Parent approval (switch)

**Validation**:
- Title required (min 3 chars)
- At least 1 assignee if rotation != manual
- Weekly: At least 1 day selected
- Monthly: Valid day (1-31)
- End date must be future

**Preview**:
- Shows next 5 occurrences with assigned users
- Example: "Mon 13 Nov - Emma, Mon 20 Nov - Noah, ..."

#### 3. RecurringTaskListScreen (`lib/features/tasks/recurring_task_list_screen.dart`)
List view of all recurring task series.

**Features**:
- Task cards with category icons
- Recurrence pattern display
- Rotation strategy badge
- Next 3 occurrences preview
- Pause/Resume button
- Edit button (opens form)
- Delete button (with confirmation)

**UI Elements**:
- Pull-to-refresh
- Empty state with illustration
- FAB for creating new task
- Card tap → Navigate to occurrence detail

#### 4. OccurrenceDetailScreen (`lib/features/tasks/occurrence_detail_screen.dart`)
View all generated occurrences of a recurring task.

**Features**:
- Grouped by month (Nov 2025, Dec 2025, etc.)
- Each occurrence shows:
  - Date + time
  - Assigned user (avatar + name)
  - Status (open/done/overdue/pending approval)
  - Points earned (if completed)

**Actions**:
- Tap occurrence → Navigate to single task detail
- Long-press → Skip occurrence / Reassign (TODO)

## API Integration

### Backend Endpoints Required

```dart
// List all recurring tasks
GET /tasks/recurring
Response: [RecurringTask]

// Create recurring task
POST /tasks/recurring
Body: {
  title, description, category, rrule,
  rotation_strategy, assignee_ids, points,
  estimated_minutes, photo_required, parent_approval
}

// Update recurring task
PUT /tasks/recurring/{id}
Body: Same as create

// Delete recurring task
DELETE /tasks/recurring/{id}

// Pause recurring task
POST /tasks/recurring/{id}/pause

// Resume recurring task
POST /tasks/recurring/{id}/resume

// Get occurrences
GET /tasks/recurring/{id}/occurrences
Response: [Occurrence]

// Preview next N occurrences with assignments
GET /tasks/recurring/{id}/preview?limit=5
Response: [OccurrencePreview]
```

### ApiClient Methods (`lib/api/client.dart`)

```dart
await ApiClient.instance.listRecurringTasks();
await ApiClient.instance.createRecurringTask(taskData);
await ApiClient.instance.updateRecurringTask(id, taskData);
await ApiClient.instance.deleteRecurringTask(id);
await ApiClient.instance.pauseRecurringTask(id);
await ApiClient.instance.resumeRecurringTask(id);
await ApiClient.instance.getOccurrences(id);
await ApiClient.instance.previewOccurrences(id, limit: 5);
```

## RRULE Format

### Examples

**Daily**:
- Every day: `FREQ=DAILY`
- Every 2 days: `FREQ=DAILY;INTERVAL=2`
- Daily for 10 times: `FREQ=DAILY;COUNT=10`

**Weekly**:
- Every Monday: `FREQ=WEEKLY;BYDAY=MO`
- Every Mon, Wed, Fri: `FREQ=WEEKLY;BYDAY=MO,WE,FR`
- Every 2 weeks on Mon: `FREQ=WEEKLY;INTERVAL=2;BYDAY=MO`

**Monthly**:
- Every 1st of month: `FREQ=MONTHLY;BYMONTHDAY=1`
- Every 15th: `FREQ=MONTHLY;BYMONTHDAY=15`

### End Conditions

**Never**: No end date/count
**Count**: `COUNT=10` (10 occurrences)
**Until**: `UNTIL=20251231T235959Z` (until date)

## Rotation Strategies

### 1. Round Robin
Fair turns for everyone. Cycles through assignees sequentially.

**Example**: Emma → Noah → Sophia → Emma → ...

### 2. Fairness
Capacity-based assignment considering:
- Current workload
- Task completion rate
- Available time slots

**Example**: User with fewer tasks gets next assignment

### 3. Random
Random assignment from available assignees.

**Example**: Random selection each occurrence

### 4. Manual
No automatic assignment. Parent assigns manually.

## Material 3 Design

### Components Used
- FilledButton for primary actions
- OutlinedButton for secondary actions
- Card with elevation 2
- SegmentedButton for frequency selector
- FilterChip for day/assignee selection
- Slider for points/duration
- Switch for boolean options

### Colors
- Category-specific colors (blue, pink, brown, purple, grey)
- Status colors (open=blue, done=green, overdue=red, pending=orange)
- Rotation strategy icons

### Animations
- Card scale-in (300ms)
- Pull-to-refresh
- Page transitions (Material route)

## Accessibility

### Screen Reader Support
- Semantic labels for all interactive elements
- Icon descriptions
- Status announcements

### Keyboard Navigation
- Tab order follows visual layout
- Enter/Space for buttons
- Arrow keys for sliders

### Contrast Ratios
- WCAG AA compliant (4.5:1 for normal text)
- Color combinations tested with contrast checker

## Testing

### Widget Tests
```dart
// Test RRuleBuilder generates correct RRULE strings
testWidgets('RRuleBuilder generates valid RRULE', (tester) async {
  String? generatedRRule;

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: RRuleBuilder(
          onRRuleChanged: (rrule) => generatedRRule = rrule,
        ),
      ),
    ),
  );

  // Select Weekly
  await tester.tap(find.text('Weekly'));
  await tester.pump();

  // Select Monday
  await tester.tap(find.text('Mon'));
  await tester.pump();

  expect(generatedRRule, contains('FREQ=WEEKLY'));
  expect(generatedRRule, contains('BYDAY=MO'));
});
```

### Integration Tests
```dart
// Test creating recurring task and viewing occurrences
testWidgets('Create recurring task flow', (tester) async {
  // Navigate to form
  await tester.tap(find.byType(FloatingActionButton));
  await tester.pumpAndSettle();

  // Fill form
  await tester.enterText(find.byType(TextField).first, 'Weekly cleaning');

  // Select category
  await tester.tap(find.text('Cleaning'));
  await tester.pump();

  // Set recurrence
  await tester.tap(find.text('Weekly'));
  await tester.pump();

  // Select assignees
  await tester.tap(find.text('Emma'));
  await tester.pump();

  // Preview
  await tester.tap(find.text('Preview Next 5 Occurrences'));
  await tester.pumpAndSettle();

  // Verify preview appears
  expect(find.byType(ListTile), findsNWidgets(5));

  // Save
  await tester.tap(find.text('Save Task'));
  await tester.pumpAndSettle();

  // Verify task appears in list
  expect(find.text('Weekly cleaning'), findsOneWidget);
});
```

## Performance Considerations

### Optimization
- Lazy loading for large occurrence lists
- Image caching for assignee avatars
- Debounced RRULE preview generation
- Efficient state management (no unnecessary rebuilds)

### Memory Management
- Dispose controllers properly
- Cancel pending requests on widget disposal
- Limit preview to 5-10 occurrences

## Future Enhancements

1. **Occurrence Actions**
   - Skip single occurrence
   - Reassign occurrence
   - Modify occurrence details

2. **Advanced Patterns**
   - Biweekly (every 2 weeks)
   - Specific weekday of month (2nd Tuesday)
   - Multiple frequencies (daily + weekly)

3. **Calendar Integration**
   - Show occurrences in calendar view
   - Drag-and-drop rescheduling
   - Visual timeline

4. **Notifications**
   - Reminder before scheduled time
   - Assignment notifications
   - Overdue alerts

5. **Analytics**
   - Completion rate per recurring task
   - Average time to complete
   - Most/least popular tasks

## Troubleshooting

### Common Issues

**Preview doesn't show**: Ensure at least 1 assignee selected and valid RRULE.

**Save fails**: Check network connection and backend endpoint availability.

**RRULE parsing error**: Validate RRULE format against RFC 5545 spec.

**Occurrences not generating**: Backend cron job may need restart.

## Backend Coordination

### Required Backend Features (100% Ready)
- RRULE expansion engine (`backend/services/recurrence.py`)
- 4 rotation strategies implemented
- API endpoints for CRUD operations
- Occurrence generation on schedule
- Database schema (recurring_tasks, occurrences tables)

### Frontend-Backend Contract
Frontend sends RRULE string, backend:
1. Validates RRULE format
2. Expands to individual occurrences
3. Applies rotation strategy
4. Assigns users to occurrences
5. Returns preview/list of occurrences
