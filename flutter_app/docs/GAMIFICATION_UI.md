# Gamification UI - FamQuest Flutter App

Complete documentation for the gamification user interface implementation.

## Overview

The gamification UI provides engaging visualizations for points, badges, streaks, and leaderboards. Built with Flutter Material 3 design system, supports offline caching with Hive, and uses Riverpod for state management.

## Architecture

### Components

1. **Widgets** - Reusable UI components
   - `PointsHUD` - Persistent points display in app bar
   - `StreakWidget` - Current streak display with fire emoji
   - `TaskCompletionDialog` - Celebration dialog after task completion
   - `BadgeUnlockAnimation` - Animated badge unlock celebration

2. **Screens** - Full-page views
   - `BadgeCatalogScreen` - Grid view of all badges (locked/unlocked)
   - `LeaderboardScreen` - Family ranking with pull-to-refresh
   - `UserStatsScreen` - Comprehensive user statistics dashboard

3. **State Management** - Riverpod providers
   - `GamificationProvider` - Reactive state for points, streaks, badges
   - `currentUserIdProvider` - Current logged-in user
   - `currentFamilyIdProvider` - Current family context

4. **API Client** - Backend communication
   - `GamificationClient` - Methods for all gamification endpoints

5. **Models** - Data classes
   - `UserStreak`, `UserBadge`, `BadgeProgress`, `LeaderboardEntry`, etc.

## File Structure

```
flutter_app/
├── lib/
│   ├── api/
│   │   └── gamification_client.dart
│   ├── models/
│   │   └── gamification_models.dart
│   ├── widgets/
│   │   ├── points_hud.dart
│   │   ├── streak_widget.dart
│   │   ├── task_completion_dialog.dart
│   │   └── badge_unlock_animation.dart
│   └── features/
│       └── gamification/
│           ├── badge_catalog_screen.dart
│           ├── leaderboard_screen.dart
│           ├── user_stats_screen.dart
│           ├── gamification_provider.dart
│           └── gamification_integration_example.dart
└── docs/
    └── GAMIFICATION_UI.md
```

## Widget Details

### PointsHUD

**Purpose**: Persistent display of current point balance in app bar.

**Features**:
- Animated counter when points change
- Tap to open user stats screen
- Material 3 chip design
- Compact and visually appealing

**Usage**:
```dart
AppBar(
  title: const Text('FamQuest'),
  actions: [
    Consumer(
      builder: (context, ref, _) {
        final points = ref.watch(pointsProvider);
        return PointsHUD(
          points: points,
          onTap: () => context.go('/gamification/stats'),
        );
      },
    ),
  ],
)
```

**Animations**:
- Scale animation (1.0 → 1.2) when points change
- 300ms duration with ease-in-out curve

### StreakWidget

**Purpose**: Display current streak with visual indicators.

**Features**:
- Fire emoji + streak count
- "X day streak!" text
- Visual indicator if streak at risk (red background)
- Longest streak display
- Compact and full view modes
- Tap to open streak detail

**Usage**:
```dart
Consumer(
  builder: (context, ref, _) {
    final streak = ref.watch(streakProvider);
    if (streak == null) return const SizedBox.shrink();

    return StreakWidget(
      streak: streak,
      compact: false, // or true for app bar
      onTap: () {
        // Navigate to streak detail
      },
    );
  },
)
```

**States**:
- **Active**: Green/orange background, current streak displayed
- **At Risk**: Red background, "Complete a task today!" message
- **Compact**: Minimal display for app bar (emoji + number only)

### TaskCompletionDialog

**Purpose**: Celebration dialog shown after completing a task.

**Features**:
- "Great job!" message with emoji
- Points breakdown (base + streak bonus)
- New streak status
- New badges (if any)
- Confetti animation background
- "Continue" button

**Usage**:
```dart
await showDialog(
  context: context,
  builder: (context) => TaskCompletionDialog(
    pointsEarned: 12,
    basePoints: 10,
    streakBonus: 2,
    newStreak: 7,
    newBadges: [badge1, badge2],
    onContinue: () {
      // Optional callback after dismissal
    },
  ),
);
```

**Animations**:
- Scale-in for celebration emoji (elastic-out curve)
- Confetti falling animation (2 seconds)
- Fade-in for badge icons

### BadgeUnlockAnimation

**Purpose**: Animated celebration for new badge unlocks.

**Features**:
- Badge icon scales in with bounce
- Sparkle effect radiating from center
- Badge name and description
- Random celebration message ("Awesome!", "Well done!", etc.)
- Auto-dismiss after 3 seconds
- Tap to dismiss immediately

**Usage**:
```dart
await showDialog(
  context: context,
  builder: (context) => BadgeUnlockAnimation(
    badge: unlockedBadge,
    onDismiss: () {
      // Optional callback
    },
  ),
);
```

**Animations**:
- Badge scale: 800ms elastic-out curve
- Sparkle particles: 2s repeating animation
- Text fade-in: 600ms after badge appears

## Screen Details

### BadgeCatalogScreen

**Purpose**: Grid view of all badges with filtering.

**Features**:
- Unlocked badges: full color with unlock date
- Locked badges: grayscale with lock icon + progress bar
- Filter chips: All / Unlocked / Locked
- Tap badge for detail dialog
- Pull to refresh
- Empty state message

**Navigation**:
```dart
context.go('/gamification/badges?userId=$userId');
```

**Layout**:
- 2-column grid
- Child aspect ratio: 0.85
- 16px spacing
- Material 3 card design

**Badge Details Dialog**:
- Large icon (80px)
- Badge name (title)
- Description (body text)
- Unlock date (if unlocked) or progress bar (if locked)

### LeaderboardScreen

**Purpose**: Family ranking with period filtering.

**Features**:
- List of family members (rank, avatar, name, points)
- Medal emojis for top 3 (🥇🥈🥉)
- Current user highlighted with "You" badge
- Period filter: Week / Month / All-Time
- Pull to refresh
- Empty state message

**Navigation**:
```dart
context.go('/gamification/leaderboard?familyId=$familyId&currentUserId=$userId');
```

**Layout**:
- List with cards
- Current user: elevated card with primary container background
- Others: flat cards with default background
- Avatar (48px), rank, name, points displayed

**Ranking**:
- Top 3: Medal emojis
- Others: Rank number
- Points with star icon

### UserStatsScreen

**Purpose**: Comprehensive user statistics dashboard.

**Features**:
- Points balance (large, centered gradient card)
- Current streak widget (full size)
- Family rank card
- Badges earned card (tap to open catalog)
- Badge preview (recent 3 badges)
- Longest streak card (if > current)
- Affordable rewards card (if any)
- Pull to refresh

**Navigation**:
```dart
context.go('/gamification/stats?userId=$userId&familyId=$familyId');
```

**Layout**:
- Scrollable column
- Large points card at top
- Streak widget below
- 2-column grid for rank + badges
- Preview cards for recent badges, longest streak, rewards

## State Management

### Providers

**currentUserIdProvider**:
```dart
final currentUserIdProvider = StateProvider<String?>((ref) => null);
```
Set after successful login.

**currentFamilyIdProvider**:
```dart
final currentFamilyIdProvider = StateProvider<String?>((ref) => null);
```
Set after successful login.

**gamificationProfileProvider**:
```dart
final gamificationProfileProvider = FutureProvider.autoDispose<GamificationProfile?>((ref) async {
  // Fetches complete profile from API
  // Caches in Hive for offline access
});
```

**pointsProvider**:
```dart
final pointsProvider = Provider.autoDispose<int>((ref) {
  // Extracts points from profile
});
```

**streakProvider**:
```dart
final streakProvider = Provider.autoDispose<UserStreak?>((ref) {
  // Extracts streak from profile
});
```

**badgesProvider**:
```dart
final badgesProvider = FutureProvider.autoDispose<List<UserBadge>>((ref) async {
  // Fetches earned badges
  // Caches in Hive
});
```

**leaderboardProvider**:
```dart
final leaderboardProvider = FutureProvider.autoDispose.family<List<LeaderboardEntry>, String>((ref, period) async {
  // Fetches leaderboard for period
  // Caches in Hive
});
```

### Refresh Operations

**Manual Refresh**:
```dart
// Refresh all gamification data
await ref.refreshGamification();
```

**After Task Completion**:
```dart
// Notify task completed (refreshes data)
await ref.notifyTaskCompleted();
```

**Optimistic UI Updates**:
```dart
// Add points optimistically (before API confirms)
ref.addPointsOptimistic(10);

// Unlock badge optimistically
ref.unlockBadgeOptimistic(badge);
```

## Offline Support

### Caching Strategy

All gamification data is cached in Hive for offline access:

**Profile Cache**:
```dart
final box = await Hive.openBox('gamification_cache');
await box.put('profile_$userId', profile.toJson());
```

**Badge Cache**:
```dart
await box.put('badges_$userId', badges.map((b) => b.toJson()).toList());
```

**Leaderboard Cache**:
```dart
await box.put('leaderboard_${familyId}_$period', entries.map((e) => e.toJson()).toList());
```

### Offline Behavior

**When Offline**:
1. API calls fail
2. Providers return cached data from Hive
3. UI shows cached state
4. Streak "at risk" indicator grayed out (can't update streak)
5. Pull-to-refresh disabled or shows error

**When Online Again**:
1. App resume triggers refresh
2. New data fetched from API
3. Cache updated
4. UI updates reactively

### Offline Indicators

```dart
final isOfflineProvider = StateProvider<bool>((ref) => false);

// Use in UI:
final isOffline = ref.watch(isOfflineProvider);
if (isOffline) {
  // Show offline banner
  // Gray out streak risk indicator
  // Disable actions that require online
}
```

## Material 3 Design

### Color Scheme

**Points**: Primary color
```dart
colorScheme.primaryContainer (background)
colorScheme.primary (text/icon)
```

**Streaks**: Orange
```dart
Colors.orange.shade50 (background)
Colors.orange.shade900 (text)
```

**At Risk Streaks**: Error color
```dart
colorScheme.errorContainer (background)
colorScheme.error (text/icon)
```

**Badges**: Per-badge color
```dart
BadgeDefinition.getColorForCode(code)
- Streak badges: Orange
- Point badges: Amber
- Task badges: Green
- Category master: Purple
```

### Typography

**Display**: Large numbers (points balance)
```dart
theme.textTheme.displayLarge
```

**Title**: Section headers, badge names
```dart
theme.textTheme.titleLarge
theme.textTheme.titleMedium
```

**Body**: Descriptions, details
```dart
theme.textTheme.bodyMedium
theme.textTheme.bodySmall
```

### Components

**Cards**: Elevated and flat
```dart
Card(elevation: 2) // Default
Card(elevation: 4) // Current user in leaderboard
Card(elevation: 1) // Locked badges
```

**Chips**: Filter selection
```dart
FilterChip(
  selected: true/false,
  onSelected: (selected) {},
)
```

**Buttons**: Filled and text
```dart
FilledButton(onPressed: () {}, child: Text('Continue'))
TextButton(onPressed: () {}, child: Text('View All'))
```

## Animations

### Scale Animations

**Points HUD** (when points change):
```dart
scale: 1.0 → 1.2
duration: 300ms
curve: easeInOut
```

**Streak Widget** (when streak increases):
```dart
scale: 1.0 → 1.3
duration: 400ms
curve: elasticOut
```

**Task Completion** (celebration emoji):
```dart
scale: 0.0 → 1.0
duration: 600ms
curve: elasticOut
```

**Badge Unlock** (badge icon):
```dart
scale: 0.0 → 1.0
duration: 800ms
curve: elasticOut
```

### Particle Animations

**Confetti** (task completion):
- 30 particles
- Random colors (red, blue, green, yellow, purple, orange)
- Fall from top, rotate during descent
- 2 second duration

**Sparkles** (badge unlock):
- 20 particles
- Badge color with 60% opacity
- Radiate from center
- Fade out as they move away
- 2 second repeating animation

## Testing Recommendations

### Unit Tests

**Models**:
```dart
test('UserStreak.fromJson parses correctly', () {
  final json = {'user_id': '123', 'current': 5, 'longest': 10};
  final streak = UserStreak.fromJson(json);
  expect(streak.current, 5);
  expect(streak.longest, 10);
});
```

**API Client**:
```dart
test('GamificationClient.getStreak returns UserStreak', () async {
  final client = GamificationClient.instance;
  final streak = await client.getStreak('user123');
  expect(streak, isA<UserStreak>());
});
```

### Widget Tests

**PointsHUD**:
```dart
testWidgets('PointsHUD displays points correctly', (tester) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(body: PointsHUD(points: 450)),
  ));
  expect(find.text('450'), findsOneWidget);
  expect(find.byIcon(Icons.star), findsOneWidget);
});
```

**StreakWidget**:
```dart
testWidgets('StreakWidget shows at-risk indicator', (tester) async {
  final streak = UserStreak(
    userId: '123',
    current: 5,
    longest: 10,
    isAtRisk: true,
  );
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(body: StreakWidget(streak: streak)),
  ));
  expect(find.text('Streak at risk!'), findsOneWidget);
});
```

### Integration Tests

**Badge Catalog Flow**:
```dart
testWidgets('BadgeCatalogScreen filters badges', (tester) async {
  await tester.pumpWidget(ProviderScope(
    child: MaterialApp(
      home: BadgeCatalogScreen(userId: 'test123'),
    ),
  ));

  await tester.pumpAndSettle();

  // Tap "Locked" filter
  await tester.tap(find.text('Locked'));
  await tester.pumpAndSettle();

  // Verify only locked badges shown
  expect(find.byIcon(Icons.lock), findsWidgets);
});
```

**Leaderboard Flow**:
```dart
testWidgets('LeaderboardScreen highlights current user', (tester) async {
  await tester.pumpWidget(ProviderScope(
    child: MaterialApp(
      home: LeaderboardScreen(
        familyId: 'family123',
        currentUserId: 'user123',
      ),
    ),
  ));

  await tester.pumpAndSettle();

  // Verify "You" badge shown for current user
  expect(find.text('You'), findsOneWidget);
});
```

### Offline Tests

**Cached Data Loading**:
```dart
test('gamificationProfileProvider returns cached data when offline', () async {
  // Pre-populate cache
  final box = await Hive.openBox('gamification_cache');
  await box.put('profile_user123', {'points': 100, 'streak': {...}});

  // Disconnect network
  // ... mock offline state

  final container = ProviderContainer();
  final profile = await container.read(gamificationProfileProvider.future);

  expect(profile?.points, 100);
});
```

## User Flows

### New User Flow

1. **Login** → Set `currentUserIdProvider`, `currentFamilyIdProvider`
2. **Home Screen** → See 0 points in HUD, no streak widget
3. **Complete First Task** → Task completion dialog shows "+10 points"
4. **Badge Unlock** → "First Task" badge animation
5. **Check Stats** → Tap HUD → See stats dashboard

### Daily Flow

1. **Open App** → Resume triggers gamification refresh
2. **Home Screen** → See current streak (or "at risk" warning)
3. **Complete Task** → Celebration dialog with points + streak bonus
4. **Check Leaderboard** → Tap menu → See family ranking
5. **View Badges** → Tap menu → See progress toward next badge

### Competitive Flow

1. **Check Rank** → See family rank in stats screen
2. **Open Leaderboard** → Compare with family members
3. **Complete Tasks** → Earn points to climb ranking
4. **Check Again** → Pull to refresh → See updated position
5. **Celebrate** → Reach #1 spot

## Troubleshooting

### Points Not Updating

**Check**:
1. Is `currentUserIdProvider` set after login?
2. Is `gamificationProfileProvider` being watched?
3. Is network connection available?
4. Check backend API logs for errors

**Fix**:
```dart
// Manual refresh
await ref.refreshGamification();
```

### Streak Not Showing

**Check**:
1. Does user have active streak (current > 0)?
2. Is `streakProvider` null or has value?
3. Is widget conditional rendering correct?

**Fix**:
```dart
final streak = ref.watch(streakProvider);
if (streak != null && streak.current > 0) {
  return StreakWidget(streak: streak);
}
```

### Badges Not Loading

**Check**:
1. Are badges cached in Hive?
2. Is API endpoint returning 200?
3. Is JSON parsing working?

**Debug**:
```dart
final badges = ref.watch(badgesProvider);
badges.when(
  data: (list) => print('Loaded ${list.length} badges'),
  loading: () => print('Loading badges...'),
  error: (err, stack) => print('Error: $err'),
);
```

### Offline Mode Not Working

**Check**:
1. Is Hive initialized (`await Hive.initFlutter()`)?
2. Are boxes opened before use?
3. Is data being cached on successful fetch?

**Fix**:
```dart
// In main.dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  runApp(const ProviderScope(child: App()));
}
```

## Performance Optimization

### Lazy Loading

All providers use `autoDispose` to cleanup when not in use:
```dart
final badgesProvider = FutureProvider.autoDispose<List<UserBadge>>(...);
```

### Caching

Data cached in Hive prevents redundant API calls:
- Profile: cached per user
- Badges: cached per user
- Leaderboard: cached per family + period

### Image Optimization

Avatars use `NetworkImage` with caching:
```dart
CircleAvatar(
  backgroundImage: entry.avatarUrl != null
    ? NetworkImage(entry.avatarUrl!)
    : null,
)
```

### Animation Efficiency

- Animations use `SingleTickerProviderStateMixin`
- Controllers disposed properly in `dispose()`
- Animations trigger only when values change

## Future Enhancements

### Planned Features

1. **Streak Detail Screen** - Full history of streak milestones
2. **Badge Rarity Tiers** - Common, rare, epic, legendary
3. **Point History Chart** - Graph of points over time
4. **Achievement Notifications** - Push notifications for badges
5. **Social Sharing** - Share badges to social media
6. **Multiplayer Challenges** - Family challenges with rewards
7. **Seasonal Badges** - Limited-time special badges
8. **Reward Redemption** - Spend points in shop

### Accessibility

- **Screen Reader**: All widgets have semantic labels
- **High Contrast**: Badge icons readable in high contrast mode
- **Font Scaling**: Text respects system font size settings
- **Color Blindness**: Badge shapes differ (not just colors)

### Internationalization

- All strings should be externalized to i18n files
- Date formatting respects user locale
- Number formatting (points, streaks) uses locale-specific separators

## Support

For issues or questions:
1. Check backend logs for API errors
2. Verify Hive database integrity
3. Test offline mode with airplane mode
4. Review Riverpod provider states with Riverpod DevTools

## Changelog

**v1.0.0** (2025-01-11):
- Initial gamification UI implementation
- Points HUD, streak widget, badges, leaderboard
- Material 3 design
- Offline caching with Hive
- Riverpod state management
- Task completion and badge unlock animations
