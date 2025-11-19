import 'package:flutter/material.dart';
import '../../core/supabase.dart';
import '../../api/client.dart';
import 'package:intl/intl.dart';
import 'dart:math';
import '../../core/app_logger.dart';

/// AI Task Planner Screen
///
/// Features:
/// - Generate AI-powered weekly task distribution
/// - Preview plan with fairness score
/// - Edit generated plan before applying
/// - Apply plan to create actual tasks
class AITaskPlannerScreen extends StatefulWidget {
  const AITaskPlannerScreen({super.key});

  @override
  State<AITaskPlannerScreen> createState() => _AITaskPlannerScreenState();
}

class _AITaskPlannerScreenState extends State<AITaskPlannerScreen> {
  // Mocha Mousse color scheme
  static const mochaBrown = Color(0xFF6B4423);
  static const lightMocha = Color(0xFFB08968);
  static const cream = Color(0xFFF5EBE0);
  static const darkMocha = Color(0xFF3D2817);

  bool isLoading = false;
  bool isGenerating = false;
  bool isApplying = false;
  Map<String, dynamic>? generatedPlan;

  String selectedWeek = 'thisWeek';
  final List<Map<String, String>> weekOptions = [
    {'value': 'thisWeek', 'label': 'Deze week'},
    {'value': 'nextWeek', 'label': 'Volgende week'},
    {'value': 'week2', 'label': 'Over 2 weken'},
  ];

  @override
  void initState() {
    super.initState();
  }

  Future<void> _generatePlan() async {
    setState(() => isGenerating = true);

    try {
      final user = currentUser;
      if (user == null) {
        throw Exception('Niet ingelogd');
      }

      // Calculate start date based on selected week
      final now = DateTime.now();
      DateTime startDate;

      switch (selectedWeek) {
        case 'nextWeek':
          startDate = now.add(const Duration(days: 7));
          break;
        case 'week2':
          startDate = now.add(const Duration(days: 14));
          break;
        default:
          startDate = now;
      }

      // Find Monday of the selected week
      startDate = startDate.subtract(Duration(days: startDate.weekday - 1));

      // REAL API CALL: Generate plan using backend AI service
      final apiClient = ApiClient.instance;
      final response = await apiClient.aiPlanWeek(
        startDate: startDate.toIso8601String().split('T')[0],
        preferences: {},
      );

      // Transform backend response to UI format
      final transformedPlan = _transformBackendPlan(response);

      if (mounted) {
        setState(() {
          generatedPlan = transformedPlan;
          isGenerating = false;
        });

        // Show success message with AI model used
        final modelUsed = response['model_used'] ?? 'AI';
        final totalTasks = response['total_tasks'] ?? 0;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Plan gegenereerd! $totalTasks taken via $modelUsed'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      AppLogger.debug('[AI_PLANNER] Error generating plan: $e');
      if (mounted) {
        setState(() => isGenerating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fout bij genereren: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Map<String, dynamic> _transformBackendPlan(Map<String, dynamic> backendPlan) {
    // Backend returns:
    // {
    //   "week_plan": [{"date": "2025-11-17", "tasks": [...]}],
    //   "fairness": {"distribution": {}, "notes": "..."},
    //   "conflicts": [],
    //   "total_tasks": 28,
    //   "cost": 0.003,
    //   "model_used": "claude-3-5-sonnet"
    // }

    final weekPlan = backendPlan['week_plan'] as List? ?? [];
    final fairness = backendPlan['fairness'] as Map<String, dynamic>? ?? {};

    // Transform to UI format (add dayName for each date)
    final transformedWeekPlan = weekPlan.map((day) {
      final date = DateTime.parse(day['date']);
      return {
        'date': day['date'],
        'dayName': DateFormat('EEEE', 'nl_NL').format(date),
        'tasks': day['tasks'] ?? [],
      };
    }).toList();

    // Calculate fairness score from distribution
    final distribution = fairness['distribution'] as Map<String, dynamic>? ?? {};
    double fairnessScore = 0.85; // Default

    if (distribution.isNotEmpty) {
      // Calculate standard deviation to determine fairness
      final values = distribution.values.map((v) => v as double).toList();
      final mean = values.reduce((a, b) => a + b) / values.length;
      final variance = values.map((v) => (v - mean) * (v - mean)).reduce((a, b) => a + b) / values.length;
      final stdDev = sqrt(variance);

      // Convert to score (lower stdDev = higher fairness)
      fairnessScore = (1.0 - stdDev).clamp(0.0, 1.0);
    }

    return {
      'weekPlan': transformedWeekPlan,
      'fairness': {
        'distribution': distribution,
        'score': fairnessScore,
        'notes': fairness['notes'] ?? 'AI-generated fair distribution',
      },
      'conflicts': backendPlan['conflicts'] ?? [],
      'total_tasks': backendPlan['total_tasks'] ?? 0,
      'model_used': backendPlan['model_used'] ?? 'AI',
    };
  }


  Future<void> _applyPlan() async {
    if (generatedPlan == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Plan toepassen?'),
        content: const Text(
          'Hiermee worden de taken uit het plan aangemaakt en toegewezen. '
          'Bestaande taken worden niet verwijderd.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuleren'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Toepassen'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => isApplying = true);

    try {
      final weekPlan = generatedPlan!['weekPlan'] as List;
      final fairness = generatedPlan!['fairness'] as Map<String, dynamic>?;

      // REAL API CALL: Apply plan using backend
      final apiClient = ApiClient.instance;
      final response = await apiClient.aiApplyPlan(
        weekPlan: weekPlan,
        fairness: fairness,
      );

      final tasksCreated = response['tasks_created'] ?? 0;
      final tasksUpdated = response['tasks_updated'] ?? 0;
      final message = response['message'] ?? 'Plan toegepast';

      if (mounted) {
        setState(() {
          isApplying = false;
          generatedPlan = null; // Clear plan after applying
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$message\n$tasksCreated nieuw, $tasksUpdated bijgewerkt'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      AppLogger.debug('[AI_PLANNER] Error applying plan: $e');
      if (mounted) {
        setState(() => isApplying = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fout bij toepassen: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: cream,
      appBar: AppBar(
        backgroundColor: mochaBrown,
        foregroundColor: Colors.white,
        title: const Text('AI Takenplanner'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Icon
            Icon(
              Icons.psychology,
              size: 64,
              color: mochaBrown.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 16),

            // Title
            Text(
              'Slimme Weekplanning',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: darkMocha,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'AI genereert een eerlijke verdeling op basis van ieders agenda en capaciteit',
              style: TextStyle(
                color: mochaBrown,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            // Week Selector
            Card(
              elevation: 2,
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Selecteer week',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: darkMocha,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...weekOptions.map((option) {
                      final isSelected = selectedWeek == option['value'];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: InkWell(
                          onTap: () => setState(() => selectedWeek = option['value']!),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? mochaBrown.withValues(alpha: 0.1)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected ? mochaBrown : lightMocha,
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Radio<String>(
                                  value: option['value']!,
                                  onChanged: (value) =>
                                      setState(() => selectedWeek = value!),
                                  activeColor: mochaBrown,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  option['label']!,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                    color: isSelected ? mochaBrown : darkMocha,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Generate Button
            if (generatedPlan == null)
              FilledButton.icon(
                onPressed: isGenerating ? null : _generatePlan,
                style: FilledButton.styleFrom(
                  backgroundColor: mochaBrown,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                icon: isGenerating
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                    : const Icon(Icons.auto_awesome),
                label: Text(isGenerating ? 'Genereren...' : 'Genereer Planning'),
              ),

            // Generated Plan Preview
            if (generatedPlan != null) ...[
              _buildPlanPreview(),
              const SizedBox(height: 24),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: isApplying
                          ? null
                          : () => setState(() => generatedPlan = null),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        foregroundColor: mochaBrown,
                        side: const BorderSide(color: mochaBrown),
                      ),
                      icon: const Icon(Icons.close),
                      label: const Text('Annuleren'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: isApplying ? null : _applyPlan,
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: isApplying
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation(Colors.white),
                              ),
                            )
                          : const Icon(Icons.check),
                      label: Text(isApplying ? 'Toepassen...' : 'Toepassen'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPlanPreview() {
    if (generatedPlan == null) return const SizedBox.shrink();

    final weekPlan = generatedPlan!['weekPlan'] as List;
    final fairness = generatedPlan!['fairness'] as Map<String, dynamic>;

    return Card(
      elevation: 4,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            const Row(
              children: [
                Icon(Icons.calendar_today, color: mochaBrown, size: 20),
                SizedBox(width: 8),
                Text(
                  'Weekplanning',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: darkMocha,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Fairness Score
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.balance, color: Colors.green, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Eerlijkheidsscore: ${(fairness['score'] * 100).toInt()}%',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.green,
                          ),
                        ),
                        Text(
                          fairness['notes'],
                          style: const TextStyle(
                            fontSize: 12,
                            color: darkMocha,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Week Days
            ...weekPlan.map((day) => _buildDayCard(day)),
          ],
        ),
      ),
    );
  }

  Widget _buildDayCard(Map<String, dynamic> day) {
    final tasks = day['tasks'] as List;
    final date = DateTime.parse(day['date']);
    final dayName = day['dayName'];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        backgroundColor: cream,
        collapsedBackgroundColor: cream,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: lightMocha),
        ),
        collapsedShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: lightMocha),
        ),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: mochaBrown.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              DateFormat('dd').format(date),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: mochaBrown,
              ),
            ),
          ),
        ),
        title: Text(
          dayName,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: darkMocha,
          ),
        ),
        subtitle: Text(
          '${tasks.length} ${tasks.length == 1 ? 'taak' : 'taken'}',
          style: const TextStyle(
            fontSize: 12,
            color: mochaBrown,
          ),
        ),
        children: tasks.map((task) => _buildTaskTile(task)).toList(),
      ),
    );
  }

  Widget _buildTaskTile(Map<String, dynamic> task) {
    return ListTile(
      dense: true,
      leading: Icon(
        _getCategoryIcon(task['category']),
        size: 20,
        color: mochaBrown,
      ),
      title: Text(
        task['title'],
        style: const TextStyle(fontSize: 14),
      ),
      subtitle: Text(
        '${task['assigneeName']} • ${task['points']} punten',
        style: const TextStyle(
          fontSize: 12,
          color: mochaBrown,
        ),
      ),
      trailing: Text(
        DateFormat('HH:mm').format(DateTime.parse(task['suggestedTime'])),
        style: const TextStyle(
          fontSize: 12,
          color: darkMocha,
        ),
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'cleaning':
        return Icons.cleaning_services;
      case 'care':
        return Icons.favorite;
      case 'pet':
        return Icons.pets;
      case 'homework':
        return Icons.school;
      default:
        return Icons.task_alt;
    }
  }
}
