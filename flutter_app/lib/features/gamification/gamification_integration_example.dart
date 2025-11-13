/// Gamification Integration Example
///
/// This file shows how to integrate gamification UI into your app.
/// Copy the relevant parts to your main.dart and home_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'badge_catalog_screen.dart';
import 'leaderboard_screen.dart';
import 'gamification_provider.dart';
import '../../widgets/points_hud.dart';
import '../../widgets/streak_widget.dart';

/// ====================================
/// STEP 1: Add routes to main.dart
/// ====================================
///
/// Add these routes to your GoRouter configuration:

/*
GoRoute(
  path: '/gamification/badges',
  builder: (c, s) {
    final userId = s.uri.queryParameters['userId']!;
    return BadgeCatalogScreen(userId: userId);
  },
),
GoRoute(
  path: '/gamification/leaderboard',
  builder: (c, s) {
    final familyId = s.uri.queryParameters['familyId']!;
    final currentUserId = s.uri.queryParameters['currentUserId']!;
    return LeaderboardScreen(
      familyId: familyId,
      currentUserId: currentUserId,
    );
  },
),
GoRoute(
  path: '/gamification/stats',
  builder: (c, s) {
    final userId = s.uri.queryParameters['userId']!;
    final familyId = s.uri.queryParameters['familyId']!;
    return UserStatsScreen(
      userId: userId,
      familyId: familyId,
    );
  },
),
*/

/// ====================================
/// STEP 2: Update AppBar to include PointsHUD
/// ====================================
///
/// Example AppBar with PointsHUD:

class ExampleAppBarWithPoints extends ConsumerWidget
    implements PreferredSizeWidget {
  const ExampleAppBarWithPoints({Key? key}) : super(key: key);

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final points = ref.watch(pointsProvider);
    final userId = ref.watch(currentUserIdProvider);
    final familyId = ref.watch(currentFamilyIdProvider);

    return AppBar(
      title: const Text('FamQuest'),
      actions: [
        // Points HUD in app bar
        PointsHUD(
          points: points,
          onTap: () {
            if (userId != null && familyId != null) {
              context.go(
                '/gamification/stats?userId=$userId&familyId=$familyId',
              );
            }
          },
        ),
        const SizedBox(width: 16),
      ],
    );
  }
}

/// ====================================
/// STEP 3: Add Gamification Menu Items
/// ====================================
///
/// Example Drawer/Menu with gamification items:

class ExampleGamificationDrawer extends ConsumerWidget {
  const ExampleGamificationDrawer({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(currentUserIdProvider);
    final familyId = ref.watch(currentFamilyIdProvider);

    return Drawer(
      child: ListView(
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(color: Colors.blue),
            child: Text(
              'FamQuest',
              style: TextStyle(color: Colors.white, fontSize: 24),
            ),
          ),

          // Home
          ListTile(
            leading: const Icon(Icons.home),
            title: const Text('Home'),
            onTap: () => context.go('/home'),
          ),

          // Calendar
          ListTile(
            leading: const Icon(Icons.calendar_today),
            title: const Text('Calendar'),
            onTap: () => context.go('/calendar'),
          ),

          const Divider(),

          // Gamification section
          ListTile(
            leading: const Icon(Icons.stars),
            title: const Text('Gamification'),
            enabled: false,
            dense: true,
          ),

          // My Stats
          ListTile(
            leading: const Icon(Icons.bar_chart),
            title: const Text('My Stats'),
            onTap: () {
              if (userId != null && familyId != null) {
                context.go(
                  '/gamification/stats?userId=$userId&familyId=$familyId',
                );
                Navigator.pop(context);
              }
            },
          ),

          // My Badges
          ListTile(
            leading: const Icon(Icons.emoji_events),
            title: const Text('My Badges'),
            onTap: () {
              if (userId != null) {
                context.go('/gamification/badges?userId=$userId');
                Navigator.pop(context);
              }
            },
          ),

          // Leaderboard
          ListTile(
            leading: const Icon(Icons.leaderboard),
            title: const Text('Leaderboard'),
            onTap: () {
              if (userId != null && familyId != null) {
                context.go(
                  '/gamification/leaderboard?familyId=$familyId&currentUserId=$userId',
                );
                Navigator.pop(context);
              }
            },
          ),

          const Divider(),

          // Settings
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('Settings'),
            onTap: () => context.go('/settings/security'),
          ),
        ],
      ),
    );
  }
}

/// ====================================
/// STEP 4: Display Streak on Home Screen
/// ====================================
///
/// Example home screen with streak widget:

class ExampleHomeScreenWithStreak extends ConsumerWidget {
  const ExampleHomeScreenWithStreak({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final streak = ref.watch(streakProvider);

    return Scaffold(
      appBar: const ExampleAppBarWithPoints(),
      drawer: const ExampleGamificationDrawer(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Streak widget at top of home screen
            if (streak != null && streak.current > 0)
              StreakWidget(
                streak: streak,
                compact: false,
                onTap: () {
                  // Could navigate to streak detail screen
                },
              ),
            const SizedBox(height: 16),

            // Rest of home screen content
            const Text('Welcome to FamQuest!'),
            // ... other widgets
          ],
        ),
      ),
    );
  }
}

/// ====================================
/// STEP 5: Show Task Completion Dialog
/// ====================================
///
/// Example: Show completion dialog after task completion

/*
// In your task completion logic:
import '../../widgets/task_completion_dialog.dart';
import '../../widgets/badge_unlock_animation.dart';

Future<void> onTaskCompleted(
  BuildContext context,
  WidgetRef ref, {
  required int pointsEarned,
  required int basePoints,
  int streakBonus = 0,
  int newStreak = 0,
  List<UserBadge> newBadges = const [],
}) async {
  // Show completion dialog
  await showDialog(
    context: context,
    builder: (context) => TaskCompletionDialog(
      pointsEarned: pointsEarned,
      basePoints: basePoints,
      streakBonus: streakBonus,
      newStreak: newStreak,
      newBadges: newBadges,
      onContinue: () {
        // Optional: navigate somewhere after completion
      },
    ),
  );

  // Show badge unlock animations
  for (final badge in newBadges) {
    await showDialog(
      context: context,
      builder: (context) => BadgeUnlockAnimation(
        badge: badge,
        onDismiss: () {
          // Optional: do something after dismissal
        },
      ),
    );
  }

  // Refresh gamification data
  await ref.refreshGamification();
}
*/

/// ====================================
/// STEP 6: Initialize User IDs on Login
/// ====================================
///
/// After successful login, set user and family IDs:

/*
// In your login success handler:
void onLoginSuccess(WidgetRef ref, String userId, String familyId) {
  ref.read(currentUserIdProvider.notifier).state = userId;
  ref.read(currentFamilyIdProvider.notifier).state = familyId;

  // Initialize gamification data
  ref.refreshGamification();
}
*/

/// ====================================
/// STEP 7: Handle App Resume (refresh data)
/// ====================================
///
/// Refresh gamification data when app resumes:

class GamificationAppLifecycleObserver extends WidgetsBindingObserver {
  final WidgetRef ref;

  GamificationAppLifecycleObserver(this.ref);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Refresh gamification data when app resumes
      ref.refreshGamification();
    }
  }
}

/*
// In your app initialization:
void initApp(WidgetRef ref) {
  final observer = GamificationAppLifecycleObserver(ref);
  WidgetsBinding.instance.addObserver(observer);
}
*/

/// ====================================
/// STEP 8: Bottom Navigation Example
/// ====================================
///
/// Example bottom navigation with gamification:

class ExampleBottomNavigation extends ConsumerStatefulWidget {
  const ExampleBottomNavigation({Key? key}) : super(key: key);

  @override
  ConsumerState<ExampleBottomNavigation> createState() =>
      _ExampleBottomNavigationState();
}

class _ExampleBottomNavigationState
    extends ConsumerState<ExampleBottomNavigation> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final userId = ref.watch(currentUserIdProvider);
    final familyId = ref.watch(currentFamilyIdProvider);

    return Scaffold(
      body: _getBody(_selectedIndex, userId, familyId),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() => _selectedIndex = index);
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(
              icon: Icon(Icons.calendar_today), label: 'Calendar'),
          NavigationDestination(
              icon: Icon(Icons.leaderboard), label: 'Leaderboard'),
          NavigationDestination(
              icon: Icon(Icons.emoji_events), label: 'Badges'),
        ],
      ),
    );
  }

  Widget _getBody(int index, String? userId, String? familyId) {
    if (userId == null || familyId == null) {
      return const Center(child: Text('Please log in'));
    }

    switch (index) {
      case 0:
        return const Center(child: Text('Home Screen'));
      case 1:
        return const Center(child: Text('Calendar Screen'));
      case 2:
        return LeaderboardScreen(
          familyId: familyId,
          currentUserId: userId,
        );
      case 3:
        return BadgeCatalogScreen(userId: userId);
      default:
        return const Center(child: Text('Unknown'));
    }
  }
}
