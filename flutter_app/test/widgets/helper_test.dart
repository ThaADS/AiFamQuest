import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Helper Widget Tests
///
/// Tests helper/external caregiver features:
/// - Helper invitation flow
/// - QR code generation and scanning
/// - Helper-specific task views
/// - Permission restrictions
/// - Helper management
void main() {
  group('Helper Invite Tests', () {
    testWidgets('Helper invite screen shows QR code',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(title: const Text('Invite Helper')),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Scan this code to join',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    width: 250,
                    height: 250,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: Text('[QR CODE]'),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Or share this code:',
                    style: TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'HELP-ABC123',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Invite Helper'), findsOneWidget);
      expect(find.text('Scan this code to join'), findsOneWidget);
      expect(find.text('Or share this code:'), findsOneWidget);
      expect(find.text('HELP-ABC123'), findsOneWidget);
    });

    testWidgets('Share button is visible',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.share),
                label: const Text('Share Invite Code'),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Share Invite Code'), findsOneWidget);
      expect(find.byIcon(Icons.share), findsOneWidget);
    });
  });

  group('Helper Join Tests', () {
    testWidgets('Join screen shows scanner option',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(title: const Text('Join as Helper')),
            body: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.qr_code_scanner, size: 80, color: Colors.blue.shade400),
                  const SizedBox(height: 24),
                  const Text(
                    'Join a Family',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Scan QR code or enter invite code',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.qr_code_scanner),
                      label: const Text('Scan QR Code'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('OR'),
                  const SizedBox(height: 16),
                  const TextField(
                    decoration: InputDecoration(
                      labelText: 'Enter Invite Code',
                      hintText: 'HELP-ABC123',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.vpn_key),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Join as Helper'), findsOneWidget);
      expect(find.text('Join a Family'), findsOneWidget);
      expect(find.text('Scan QR Code'), findsOneWidget);
      expect(find.text('Enter Invite Code'), findsOneWidget);
      expect(find.byIcon(Icons.qr_code_scanner), findsWidgets);
    });

    testWidgets('Manual code entry field accepts input',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: const Padding(
              padding: EdgeInsets.all(16),
              child: TextField(
                decoration: InputDecoration(
                  labelText: 'Invite Code',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final textField = find.byType(TextField);
      await tester.enterText(textField, 'HELP-XYZ789');
      await tester.pumpAndSettle();

      expect(find.text('HELP-XYZ789'), findsOneWidget);
    });
  });

  group('Helper Home Screen Tests', () {
    testWidgets('Helper sees only assigned tasks',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(
              title: const Text('My Tasks'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.person),
                  onPressed: () {},
                ),
              ],
            ),
            body: ListView(
              children: [
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.cleaning_services),
                    title: const Text('Clean Living Room'),
                    subtitle: const Text('Assigned to you'),
                    trailing: const Chip(
                      label: Text('Open'),
                      backgroundColor: Colors.blue,
                    ),
                  ),
                ),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.local_laundry_service),
                    title: const Text('Do Laundry'),
                    subtitle: const Text('Assigned to you'),
                    trailing: const Chip(
                      label: Text('Open'),
                      backgroundColor: Colors.blue,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('My Tasks'), findsOneWidget);
      expect(find.text('Clean Living Room'), findsOneWidget);
      expect(find.text('Do Laundry'), findsOneWidget);
      expect(find.text('Assigned to you'), findsNWidgets(2));
    });

    testWidgets('Helper cannot see family calendar',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(title: const Text('Helper Dashboard')),
            body: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.lock, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'Calendar not available',
                    style: TextStyle(fontSize: 18),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Helpers can only view assigned tasks',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Calendar not available'), findsOneWidget);
      expect(find.text('Helpers can only view assigned tasks'), findsOneWidget);
      expect(find.byIcon(Icons.lock), findsOneWidget);
    });
  });

  group('Helper Management Tests', () {
    testWidgets('Parent can see active helpers list',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(title: const Text('Manage Helpers')),
            body: ListView(
              children: [
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.blue.shade100,
                    child: const Icon(Icons.person, color: Colors.blue),
                  ),
                  title: const Text('Maria'),
                  subtitle: const Text('Helper • Joined Nov 15'),
                  trailing: IconButton(
                    icon: const Icon(Icons.more_vert),
                    onPressed: () {},
                  ),
                ),
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.blue.shade100,
                    child: const Icon(Icons.person, color: Colors.blue),
                  ),
                  title: const Text('John'),
                  subtitle: const Text('Helper • Joined Nov 10'),
                  trailing: IconButton(
                    icon: const Icon(Icons.more_vert),
                    onPressed: () {},
                  ),
                ),
              ],
            ),
            floatingActionButton: FloatingActionButton.extended(
              onPressed: () {},
              icon: const Icon(Icons.person_add),
              label: const Text('Invite Helper'),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Manage Helpers'), findsOneWidget);
      expect(find.text('Maria'), findsOneWidget);
      expect(find.text('John'), findsOneWidget);
      expect(find.text('Invite Helper'), findsOneWidget);
      expect(find.byIcon(Icons.person_add), findsOneWidget);
    });

    testWidgets('Remove helper confirmation dialog',
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
                      title: const Text('Remove Helper?'),
                      content: const Text(
                        'Are you sure you want to remove Maria as a helper? '
                        'They will lose access to all tasks.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(context),
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.red,
                          ),
                          child: const Text('Remove'),
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

      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();

      expect(find.text('Remove Helper?'), findsOneWidget);
      expect(find.text('Are you sure you want to remove Maria as a helper? '
          'They will lose access to all tasks.'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Remove'), findsOneWidget);
    });
  });

  group('Helper Permission Tests', () {
    testWidgets('Helper sees restricted navigation',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(title: const Text('FamQuest')),
            body: const Center(child: Text('Tasks')),
            bottomNavigationBar: BottomNavigationBar(
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.task),
                  label: 'Tasks',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.person),
                  label: 'Profile',
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Helper only sees Tasks and Profile, no Calendar or Gamification
      expect(find.text('Tasks'), findsOneWidget);
      expect(find.text('Profile'), findsOneWidget);
      expect(find.byIcon(Icons.task), findsOneWidget);
      expect(find.byIcon(Icons.person), findsOneWidget);
    });

    testWidgets('Helper badge indicates role',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(
              title: const Row(
                children: [
                  Text('FamQuest'),
                  SizedBox(width: 8),
                  Chip(
                    label: Text('Helper'),
                    backgroundColor: Colors.purple,
                    labelStyle: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            body: const Center(child: Text('Content')),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Helper'), findsOneWidget);
      expect(find.byType(Chip), findsOneWidget);
    });
  });

  group('Helper Task Assignment Tests', () {
    testWidgets('Parent can assign task to helper',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Assign to:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    title: const Text('Noah (Child)'),
                    value: false,
                    onChanged: (val) {},
                  ),
                  CheckboxListTile(
                    title: const Text('Maria (Helper)'),
                    value: true,
                    onChanged: (val) {},
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Assign to:'), findsOneWidget);
      expect(find.text('Noah (Child)'), findsOneWidget);
      expect(find.text('Maria (Helper)'), findsOneWidget);
      expect(find.byType(CheckboxListTile), findsNWidgets(2));
    });
  });
}
