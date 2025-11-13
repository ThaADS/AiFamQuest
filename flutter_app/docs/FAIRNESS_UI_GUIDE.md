# Fairness Engine UI Guide

## Overview
The Fairness Engine UI provides visual insights into workload distribution across family members, helping parents ensure fair task allocation and identify imbalances.

## Features Implemented

### 1. Fairness Dashboard (`lib/features/fairness/fairness_dashboard_screen.dart`)

Main screen displaying comprehensive workload analysis:

**Components:**
- **Fairness Score Card**: Overall family balance metric (0-100%)
  - Excellent: ≥90% (green)
  - Good: 80-89% (blue)
  - Fair: 70-79% (orange)
  - Unbalanced: <70% (red)

- **Date Range Filter**: Three-option segmented button
  - This Week
  - This Month
  - All Time

- **Capacity Bars**: Individual family member workload visualization
  - Avatar + name
  - Progress bar (0-150% capacity)
  - Hours used / total capacity
  - Task count
  - Status badge (Light/Moderate/High/Overloaded)

- **Task Distribution Chart**: Pie chart showing % of tasks per user
  - Interactive legend
  - Tap slice to filter (future enhancement)

- **Fairness Insights**: AI-generated recommendations
  - Workload imbalance alerts
  - Performance highlights
  - Rebalance suggestions

### 2. Reusable Widgets

#### Capacity Bar (`lib/widgets/capacity_bar.dart`)
Displays user workload with color-coded status:
```dart
CapacityBar(
  workload: userWorkload,
  onTap: () => navigateToUserProfile(),
)
```

**Features:**
- Automatic color coding based on capacity percentage
- Status chips (Light/Moderate/High/Overloaded)
- User avatar with fallback initials
- Hours and task count display

#### Task Distribution Chart (`lib/widgets/task_distribution_chart.dart`)
Pie chart visualization using fl_chart:
```dart
TaskDistributionChart(
  distribution: {'userId': taskCount},
  workloads: workloadsMap,
  onUserSelected: (userId) => filterTasks(userId),
)
```

**Features:**
- Auto-generated color palette
- Interactive touch feedback
- Legend with percentages
- Empty state handling

#### Fairness Insights Card (`lib/widgets/fairness_insights_card.dart`)
Displays AI insights with contextual icons:
```dart
FairnessInsightsCard(
  insights: ['Noah is 15% above average', ...],
  onRebalance: () => openAiPlanner(),
)
```

**Features:**
- Automatic insight categorization (warning/opportunity/success/info)
- Color-coded icons
- Rebalance action button

## Data Models

### FairnessData (`lib/models/fairness_models.dart`)
```dart
class FairnessData {
  final double fairnessScore;              // 0.0-1.0
  final Map<String, UserWorkload> workloads;
  final Map<String, int> taskDistribution;
  final DateTime startDate;
  final DateTime endDate;
}
```

### UserWorkload
```dart
class UserWorkload {
  final String userId;
  final double usedHours;
  final double totalCapacity;
  final int tasksCompleted;
  final double percentage;
  final String? userName;
  final String? userAvatar;
}
```

### Enums
- `FairnessStatus`: excellent, good, fair, unbalanced
- `CapacityStatus`: light, moderate, high, overloaded
- `DateRange`: thisWeek, thisMonth, allTime

## API Integration

### Required Backend Endpoints

1. **GET /fairness/family/{familyId}**
   - Query params: `range` (this_week, this_month, all_time)
   - Returns: FairnessData JSON
   ```json
   {
     "fairness_score": 0.85,
     "workloads": {
       "user123": {
         "user_id": "user123",
         "user_name": "Noah",
         "user_avatar": "https://...",
         "used_hours": 3.5,
         "total_capacity": 4.0,
         "tasks_completed": 7,
         "percentage": 87.5
       }
     },
     "task_distribution": {
       "user123": 7,
       "user456": 5
     },
     "start_date": "2025-11-05T00:00:00Z",
     "end_date": "2025-11-11T23:59:59Z"
   }
   ```

2. **GET /fairness/insights/{familyId}**
   - Returns: List of insight strings
   ```json
   {
     "insights": [
       "Noah is 15% above average this week",
       "Luna has lightest load - consider assigning more tasks",
       "Sam completed all tasks on time (100% streak)"
     ]
   }
   ```

## Riverpod Providers

### Fairness Provider (`lib/features/fairness/fairness_provider.dart`)
```dart
// Main data provider with date range
final fairnessProvider = FutureProvider.family<FairnessData, DateRange>(...);

// Insights provider
final fairnessInsightsProvider = FutureProvider.autoDispose<List<String>>(...);

// UI state providers
final selectedDateRangeProvider = StateProvider<DateRange>(...);
final selectedUserIdProvider = StateProvider<String?>(...);
```

## Navigation Integration

Add to your router configuration:
```dart
GoRoute(
  path: '/fairness',
  builder: (context, state) => const FairnessDashboardScreen(),
),
```

Access from parent menu:
```dart
ListTile(
  leading: const Icon(Icons.balance),
  title: const Text('Workload Balance'),
  onTap: () => context.go('/fairness'),
)
```

## Material 3 Design

All components follow Material 3 design guidelines:
- Color scheme from theme
- Elevation levels: Card (2), elevated components (4)
- Border radius: 12px for cards, 8px for chips
- Spacing: 16px base unit
- Typography: Material 3 text styles

## Responsive Behavior

- **Phone**: Single column layout
- **Tablet**: Optimized for larger screens (future enhancement)
- **Landscape**: Adapts automatically

## Accessibility

- Semantic labels for screen readers
- High contrast color coding
- Touch targets ≥48dp
- Keyboard navigation support

## Testing

### Widget Tests
Create `test/widgets/capacity_bar_test.dart`:
```dart
testWidgets('CapacityBar displays correct percentage', (tester) async {
  final workload = UserWorkload(
    userId: 'test',
    usedHours: 3.0,
    totalCapacity: 4.0,
    tasksCompleted: 5,
    percentage: 75.0,
  );

  await tester.pumpWidget(
    MaterialApp(home: CapacityBar(workload: workload)),
  );

  expect(find.text('75%'), findsOneWidget);
  expect(find.text('3.0h / 4h'), findsOneWidget);
});
```

### Integration Tests
Create `integration_test/fairness_test.dart`:
```dart
testWidgets('Fairness dashboard loads and displays data', (tester) async {
  await tester.pumpWidget(MyApp());
  await tester.tap(find.text('Workload Balance'));
  await tester.pumpAndSettle();

  expect(find.byType(FairnessDashboardScreen), findsOneWidget);
  expect(find.byType(CapacityBar), findsWidgets);
});
```

## Future Enhancements

1. **User Filtering**: Tap user to see their detailed task history
2. **Trend Charts**: Show workload trends over time
3. **Export Reports**: PDF export of fairness analysis
4. **Notifications**: Alert parents when imbalance detected
5. **Tablet Optimization**: Side-by-side layout for larger screens
6. **Offline Support**: Cache fairness data for offline viewing

## Troubleshooting

### Issue: Fairness score always shows 0%
**Solution**: Ensure backend is calculating fairness_score correctly and returning 0.0-1.0 range.

### Issue: Charts not rendering
**Solution**: Verify fl_chart version 0.65.0 is installed (`flutter pub get`).

### Issue: Empty state not showing
**Solution**: Check API returns empty arrays/maps when no data available.

## Performance Optimization

- Fairness data cached with `FutureProvider` (auto-refresh on invalidate)
- Insights loaded separately to avoid blocking main UI
- Date range changes trigger selective refetch
- Chart data pre-processed for faster rendering
