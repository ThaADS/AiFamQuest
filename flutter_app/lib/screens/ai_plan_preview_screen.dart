import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../api/client.dart';

class AIPlanPreviewScreen extends StatefulWidget {
  final String familyId;
  final Map<String, dynamic> weekPlan;
  final Map<String, String> userIdToName;

  const AIPlanPreviewScreen({
    super.key,
    required this.familyId,
    required this.weekPlan,
    required this.userIdToName,
  });

  @override
  State<AIPlanPreviewScreen> createState() => _AIPlanPreviewScreenState();
}

class _AIPlanPreviewScreenState extends State<AIPlanPreviewScreen> {
  bool _isCreatingTasks = false;
  final Set<String> _editedTaskIds = {};

  @override
  Widget build(BuildContext context) {
    final weekPlanList = widget.weekPlan['weekPlan'] as List<dynamic>;
    final fairness = widget.weekPlan['fairness'] as Map<String, dynamic>;
    final distribution = fairness['distribution'] as Map<String, dynamic>;

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Weekly Plan Preview'),
        backgroundColor: Colors.deepPurple,
      ),
      body: Column(
        children: [
          // Fairness Distribution Summary
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.deepPurple.shade50,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.balance, color: Colors.deepPurple),
                    const SizedBox(width: 8),
                    Text(
                      'Fairness Distribution',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...distribution.entries.map((entry) {
                  final userName = widget.userIdToName[entry.key] ?? 'Unknown';
                  final percentage = ((entry.value as num) * 100).toStringAsFixed(0);
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Text(
                            userName,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: LinearProgressIndicator(
                            value: entry.value as double,
                            backgroundColor: Colors.grey.shade300,
                            color: Colors.deepPurple,
                            minHeight: 8,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text('$percentage%'),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 8),
                Text(
                  fairness['notes'] as String,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),

          // Week Plan
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: weekPlanList.length,
              itemBuilder: (context, index) {
                final dayPlan = weekPlanList[index] as Map<String, dynamic>;
                final date = dayPlan['date'] as String;
                final tasks = dayPlan['tasks'] as List<dynamic>;
                final dateObj = DateTime.parse(date);
                final dayName = DateFormat('EEEE').format(dateObj);
                final dayMonth = DateFormat('MMM d').format(dateObj);

                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: ExpansionTile(
                    title: Text(
                      '$dayName, $dayMonth',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text('${tasks.length} tasks'),
                    children: tasks.map((task) {
                      final taskMap = task as Map<String, dynamic>;
                      final assigneeName = widget.userIdToName[taskMap['assignee']] ?? 'Unknown';
                      final suggestedTime = DateTime.parse(taskMap['suggestedTime']);
                      final timeStr = DateFormat('HH:mm').format(suggestedTime);
                      final isEdited = _editedTaskIds.contains(taskMap['taskId']);

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isEdited ? Colors.orange : Colors.deepPurple,
                          child: Text(
                            assigneeName[0].toUpperCase(),
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        title: Text(taskMap['title']),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Assigned to: $assigneeName'),
                            Text('Time: $timeStr'),
                            Text(
                              'Reason: ${taskMap['reason']}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isEdited)
                              const Icon(
                                Icons.edit,
                                color: Colors.orange,
                                size: 16,
                              ),
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 20),
                              onPressed: () => _editTaskAssignment(context, taskMap),
                            ),
                          ],
                        ),
                        isThreeLine: true,
                      );
                    }).toList(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.shade300,
              blurRadius: 4,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Cancel'),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton(
                onPressed: _isCreatingTasks ? null : _createTasksFromPlan,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isCreatingTasks
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Create Tasks'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _editTaskAssignment(BuildContext context, Map<String, dynamic> task) {
    // Show dialog to reassign task to different user
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit ${task['title']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Reassign to:'),
            const SizedBox(height: 8),
            ...widget.userIdToName.entries.map((entry) {
              final isCurrentAssignee = entry.key == task['assignee'];
              return RadioListTile<String>(
                title: Text(entry.value),
                value: entry.key,
                groupValue: task['assignee'],
                selected: isCurrentAssignee,
                onChanged: (value) {
                  setState(() {
                    task['assignee'] = value;
                    _editedTaskIds.add(task['taskId']);
                  });
                  Navigator.pop(context);
                },
              );
            }),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> _createTasksFromPlan() async {
    setState(() => _isCreatingTasks = true);

    try {
      final weekPlanList = widget.weekPlan['weekPlan'] as List<dynamic>;
      int createdCount = 0;

      for (final dayPlan in weekPlanList) {
        final tasks = (dayPlan as Map<String, dynamic>)['tasks'] as List<dynamic>;

        for (final task in tasks) {
          final taskMap = task as Map<String, dynamic>;

          await ApiClient.instance.createTask({
            'title': taskMap['title'],
            'assignees': [taskMap['assignee']],
            'due': taskMap['suggestedTime'],
            'category': 'ai_planned',
            'status': 'open',
            'points': 10,
            'description': 'AI Planned Task: ${taskMap['reason']}',
          });

          createdCount++;
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully created $createdCount tasks!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true); // Return true to indicate success
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create tasks: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCreatingTasks = false);
      }
    }
  }
}
