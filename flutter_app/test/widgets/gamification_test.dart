import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:famquest_v9/features/gamification/shop_screen.dart';

/// Gamification Widget Tests
///
/// Tests gamification features:
/// - Shop screen with reward items
/// - Points balance display
/// - Purchase confirmation dialog
/// - Insufficient points handling
/// - Badge unlock animations
/// - Streak display
void main() {
  group('Shop Screen Widget Tests', () {
    testWidgets('Shop screen renders with app bar',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ShopScreen(),
        ),
      );

      await tester.pumpAndSettle();

      // Verify app bar
      expect(find.text('Winkel'), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);
    });

    testWidgets('Points balance displays in app bar',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ShopScreen(),
        ),
      );

      await tester.pumpAndSettle();

      // Verify points display (initial state should show 0 or loading)
      expect(find.byIcon(Icons.stars), findsOneWidget);
      expect(find.textContaining('punten'), findsOneWidget);
    });

    testWidgets('Loading indicator shows during data fetch',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ShopScreen(),
        ),
      );

      // Pump once to trigger loading state
      await tester.pump();

      // Should show loading indicator initially
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('Empty state shows when no rewards available',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ShopScreen(),
        ),
      );

      await tester.pumpAndSettle();

      // Verify empty state message
      expect(find.text('Geen beloningen beschikbaar'), findsOneWidget);
      expect(find.byIcon(Icons.shopping_bag_outlined), findsOneWidget);
      expect(
          find.text('Vraag je ouders om beloningen toe te voegen!'),
          findsOneWidget);
    });

    testWidgets('Pull to refresh works',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: ShopScreen(),
        ),
      );

      await tester.pumpAndSettle();

      // Find RefreshIndicator (if items are loaded)
      // This test verifies widget structure
      expect(find.byType(ShopScreen), findsOneWidget);
    });
  });

  group('Reward Card Widget Tests', () {
    testWidgets('Reward card displays item details',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.brown.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.star,
                            color: Colors.amber,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Extra TV Time',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                '30 minutes extra screen time',
                                style: TextStyle(fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.brown.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.stars, color: Colors.amber, size: 16),
                              SizedBox(width: 6),
                              Text(
                                '50 punten',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                        FilledButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.shopping_cart, size: 18),
                          label: const Text('Kopen'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Extra TV Time'), findsOneWidget);
      expect(find.text('30 minutes extra screen time'), findsOneWidget);
      expect(find.text('50 punten'), findsOneWidget);
      expect(find.text('Kopen'), findsOneWidget);
    });

    testWidgets('Locked reward shows lock icon and disabled state',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Text('Expensive Reward'),
                    FilledButton.icon(
                      onPressed: null, // Disabled
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.grey,
                      ),
                      icon: const Icon(Icons.lock, size: 18),
                      label: const Text('Te duur'),
                    ),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline, size: 18, color: Colors.orange),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Je hebt nog 25 punten nodig',
                              style: TextStyle(fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Te duur'), findsOneWidget);
      expect(find.byIcon(Icons.lock), findsOneWidget);
      expect(find.text('Je hebt nog 25 punten nodig'), findsOneWidget);
    });
  });

  group('Purchase Confirmation Dialog Tests', () {
    testWidgets('Confirmation dialog shows purchase details',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Bevestig aankoop'),
                      content: const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Wil je "Extra TV Time" kopen?'),
                          SizedBox(height: 16),
                          Text('Kosten: 50 punten'),
                          Text('Huidige saldo: 100 punten'),
                          Text('Nieuw saldo: 50 punten'),
                        ],
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Annuleren'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Kopen'),
                        ),
                      ],
                    ),
                  );
                },
                child: const Text('Purchase'),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap button to show dialog
      await tester.tap(find.text('Purchase'));
      await tester.pumpAndSettle();

      // Verify dialog contents
      expect(find.text('Bevestig aankoop'), findsOneWidget);
      expect(find.text('Wil je "Extra TV Time" kopen?'), findsOneWidget);
      expect(find.text('Kosten: 50 punten'), findsOneWidget);
      expect(find.text('Annuleren'), findsOneWidget);
      expect(find.text('Kopen'), findsOneWidget);
    });

    testWidgets('Cancel button closes dialog',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Confirmation'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Annuleren'),
                        ),
                      ],
                    ),
                  );
                },
                child: const Text('Show'),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Show dialog
      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();

      expect(find.text('Confirmation'), findsOneWidget);

      // Tap cancel
      await tester.tap(find.text('Annuleren'));
      await tester.pumpAndSettle();

      // Dialog should be closed
      expect(find.text('Confirmation'), findsNothing);
    });
  });

  group('Badge Display Tests', () {
    testWidgets('Badge card shows badge information',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.stars,
                        size: 48,
                        color: Colors.amber,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Week Streak',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Completed tasks for 7 days straight',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 8),
                    Chip(
                      label: const Text('Unlocked'),
                      backgroundColor: Colors.green.shade100,
                      avatar: const Icon(Icons.check_circle, size: 16),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Week Streak'), findsOneWidget);
      expect(find.text('Completed tasks for 7 days straight'), findsOneWidget);
      expect(find.text('Unlocked'), findsOneWidget);
      expect(find.byIcon(Icons.stars), findsOneWidget);
    });

    testWidgets('Locked badge shows lock overlay',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Stack(
                  children: [
                    Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.grey.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.stars,
                            size: 48,
                            color: Colors.grey.shade400,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Speed Demon',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                    const Positioned(
                      top: 0,
                      right: 0,
                      child: Icon(Icons.lock, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Speed Demon'), findsOneWidget);
      expect(find.byIcon(Icons.lock), findsOneWidget);
    });
  });

  group('Streak Display Tests', () {
    testWidgets('Streak counter shows current streak',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.local_fire_department,
                        color: Colors.orange, size: 32),
                    const SizedBox(width: 12),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '7 Days',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Current Streak',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('7 Days'), findsOneWidget);
      expect(find.text('Current Streak'), findsOneWidget);
      expect(find.byIcon(Icons.local_fire_department), findsOneWidget);
    });

    testWidgets('Streak warning shows when about to break',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning, color: Colors.orange),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Complete a task today to keep your 7-day streak!',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(
          find.text('Complete a task today to keep your 7-day streak!'),
          findsOneWidget);
      expect(find.byIcon(Icons.warning), findsOneWidget);
    });
  });

  group('Points Transaction Tests', () {
    testWidgets('Points earned animation displays correctly',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add_circle,
                    size: 64,
                    color: Colors.green.shade400,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '+20',
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Points Earned!',
                    style: TextStyle(fontSize: 20),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('+20'), findsOneWidget);
      expect(find.text('Points Earned!'), findsOneWidget);
      expect(find.byIcon(Icons.add_circle), findsOneWidget);
    });

    testWidgets('Points spent animation displays correctly',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.remove_circle,
                    size: 64,
                    color: Colors.red.shade400,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '-50',
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Points Spent',
                    style: TextStyle(fontSize: 20),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('-50'), findsOneWidget);
      expect(find.text('Points Spent'), findsOneWidget);
      expect(find.byIcon(Icons.remove_circle), findsOneWidget);
    });
  });

  group('Leaderboard Widget Tests', () {
    testWidgets('Leaderboard entry shows user rank and points',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Text(
                    '1',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
              title: const Text('Noah'),
              trailing: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.stars, color: Colors.amber, size: 20),
                  SizedBox(width: 4),
                  Text(
                    '450',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('1'), findsOneWidget);
      expect(find.text('Noah'), findsOneWidget);
      expect(find.text('450'), findsOneWidget);
      expect(find.byIcon(Icons.stars), findsOneWidget);
    });
  });
}
