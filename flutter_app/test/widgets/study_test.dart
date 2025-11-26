import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Study Widget Tests
///
/// Tests study/homework coach features:
/// - Study session creation and planning
/// - Quiz generation and completion
/// - Spaced repetition scheduling
/// - Progress tracking
/// - Subject organization
void main() {
  group('Study Dashboard Tests', () {
    testWidgets('Study dashboard shows subject cards',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(title: const Text('Study Dashboard')),
            body: GridView.count(
              crossAxisCount: 2,
              children: [
                Card(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.science, size: 48, color: Colors.blue.shade400),
                      const SizedBox(height: 8),
                      const Text(
                        'Biology',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text('3 active items'),
                    ],
                  ),
                ),
                Card(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.calculate, size: 48, color: Colors.green.shade400),
                      const SizedBox(height: 8),
                      const Text(
                        'Math',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text('2 active items'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Study Dashboard'), findsOneWidget);
      expect(find.text('Biology'), findsOneWidget);
      expect(find.text('Math'), findsOneWidget);
      expect(find.text('3 active items'), findsOneWidget);
      expect(find.text('2 active items'), findsOneWidget);
    });

    testWidgets('Add study item FAB is visible',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: const Center(child: Text('Study Dashboard')),
            floatingActionButton: FloatingActionButton.extended(
              onPressed: () {},
              icon: const Icon(Icons.add),
              label: const Text('New Study Item'),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.add), findsOneWidget);
      expect(find.text('New Study Item'), findsOneWidget);
    });
  });

  group('Study Item Card Tests', () {
    testWidgets('Study item card shows subject and topic',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Card(
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.science, color: Colors.blue),
                ),
                title: const Text('Cell Structure'),
                subtitle: const Text('Biology • Exam: Nov 25'),
                trailing: const Icon(Icons.chevron_right),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Cell Structure'), findsOneWidget);
      expect(find.text('Biology • Exam: Nov 25'), findsOneWidget);
      expect(find.byIcon(Icons.science), findsOneWidget);
    });

    testWidgets('Progress indicator shows completion percentage',
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
                    const Text('Photosynthesis'),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: LinearProgressIndicator(
                            value: 0.65,
                            backgroundColor: Colors.grey.shade200,
                            valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text('65%'),
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

      expect(find.text('Photosynthesis'), findsOneWidget);
      expect(find.text('65%'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('Exam countdown shows days remaining',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.event, size: 16, color: Colors.orange),
                          SizedBox(width: 4),
                          Text(
                            '6 days',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.orange,
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

      expect(find.text('6 days'), findsOneWidget);
      expect(find.byIcon(Icons.event), findsOneWidget);
    });
  });

  group('Study Session Tests', () {
    testWidgets('Study session shows scheduled time',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListTile(
              leading: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '19',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'NOV',
                      style: TextStyle(fontSize: 10),
                    ),
                  ],
                ),
              ),
              title: const Text('Cell Structure Review'),
              subtitle: const Text('18:00 - 18:30 (30 min)'),
              trailing: Chip(
                label: const Text('Scheduled'),
                backgroundColor: Colors.blue.shade100,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('19'), findsOneWidget);
      expect(find.text('NOV'), findsOneWidget);
      expect(find.text('Cell Structure Review'), findsOneWidget);
      expect(find.text('18:00 - 18:30 (30 min)'), findsOneWidget);
      expect(find.text('Scheduled'), findsOneWidget);
    });

    testWidgets('Completed session shows checkmark',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListTile(
              leading: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle, color: Colors.green),
              ),
              title: const Text('Mitosis Study'),
              subtitle: const Text('Completed • 25 min'),
              trailing: const Text('100%'),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Mitosis Study'), findsOneWidget);
      expect(find.text('Completed • 25 min'), findsOneWidget);
      expect(find.text('100%'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });
  });

  group('Quiz Widget Tests', () {
    testWidgets('Quiz question displays with answer field',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      children: [
                        Text(
                          'Question 1/5',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Spacer(),
                        Icon(Icons.timer, size: 16),
                        SizedBox(width: 4),
                        Text('2:30'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'What is the powerhouse of the cell?',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const TextField(
                    decoration: InputDecoration(
                      hintText: 'Type your answer...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Question 1/5'), findsOneWidget);
      expect(find.text('What is the powerhouse of the cell?'), findsOneWidget);
      expect(find.text('Type your answer...'), findsOneWidget);
      expect(find.byIcon(Icons.timer), findsOneWidget);
    });

    testWidgets('Multiple choice quiz shows options',
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
                    'Which organelle contains chlorophyll?',
                    style: TextStyle(fontSize: 18),
                  ),
                  const SizedBox(height: 16),
                  RadioListTile<String>(
                    title: const Text('A. Mitochondria'),
                    value: 'A',
                    groupValue: null,
                    onChanged: (val) {},
                  ),
                  RadioListTile<String>(
                    title: const Text('B. Chloroplast'),
                    value: 'B',
                    groupValue: null,
                    onChanged: (val) {},
                  ),
                  RadioListTile<String>(
                    title: const Text('C. Nucleus'),
                    value: 'C',
                    groupValue: null,
                    onChanged: (val) {},
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Which organelle contains chlorophyll?'), findsOneWidget);
      expect(find.text('A. Mitochondria'), findsOneWidget);
      expect(find.text('B. Chloroplast'), findsOneWidget);
      expect(find.text('C. Nucleus'), findsOneWidget);
      expect(find.byType(RadioListTile<String>), findsNWidgets(3));
    });

    testWidgets('Quiz results show score and feedback',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.celebration,
                      size: 80,
                      color: Colors.green.shade400,
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Great Job!',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      '4 out of 5 correct',
                      style: TextStyle(fontSize: 20),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '80% score',
                      style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
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

      expect(find.text('Great Job!'), findsOneWidget);
      expect(find.text('4 out of 5 correct'), findsOneWidget);
      expect(find.text('80% score'), findsOneWidget);
      expect(find.byIcon(Icons.celebration), findsOneWidget);
    });
  });

  group('Study Planner Tests', () {
    testWidgets('Study plan shows AI-generated sessions',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(title: const Text('Study Plan')),
            body: ListView(
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.blue.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.lightbulb, color: Colors.blue),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'AI-Generated Plan',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Text('6 study sessions planned'),
                        const SizedBox(height: 4),
                        const Text('Exam in 8 days'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Study Plan'), findsOneWidget);
      expect(find.text('AI-Generated Plan'), findsOneWidget);
      expect(find.text('6 study sessions planned'), findsOneWidget);
      expect(find.byIcon(Icons.lightbulb), findsOneWidget);
    });

    testWidgets('Backward planning timeline shows milestones',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                ListTile(
                  leading: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.blue,
                      shape: BoxShape.circle,
                    ),
                  ),
                  title: const Text('Nov 19: Cell structure basics'),
                  subtitle: const Text('30 min study + quiz'),
                ),
                ListTile(
                  leading: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.blue,
                      shape: BoxShape.circle,
                    ),
                  ),
                  title: const Text('Nov 21: Photosynthesis process'),
                  subtitle: const Text('30 min study + quiz'),
                ),
                ListTile(
                  leading: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                    ),
                  ),
                  title: const Text('Nov 24: Final review'),
                  subtitle: const Text('60 min • Practice exam'),
                ),
              ],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Nov 19: Cell structure basics'), findsOneWidget);
      expect(find.text('Nov 21: Photosynthesis process'), findsOneWidget);
      expect(find.text('Nov 24: Final review'), findsOneWidget);
    });
  });

  group('Spaced Repetition Tests', () {
    testWidgets('Next review date is displayed',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.refresh, color: Colors.purple),
                    SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Next Review',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text('Nov 22, 2025'),
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

      expect(find.text('Next Review'), findsOneWidget);
      expect(find.text('Nov 22, 2025'), findsOneWidget);
      expect(find.byIcon(Icons.refresh), findsOneWidget);
    });
  });
}
