/// Occurrence detail screen
///
/// Shows all generated occurrences of a recurring task with full task details
/// and action buttons (edit, delete, mark done)

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/recurring_task_models.dart';
import '../../api/client.dart';
import '../../widgets/rrule_display.dart';
import 'recurring_task_form.dart';

class OccurrenceDetailScreen extends StatefulWidget {
  final RecurringTask task;

  const OccurrenceDetailScreen({Key? key, required this.task})
      : super(key: key);

  @override
  State<OccurrenceDetailScreen> createState() => _OccurrenceDetailScreenState();
}

class _OccurrenceDetailScreenState extends State<OccurrenceDetailScreen> {
  List<Occurrence> _occurrences = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadOccurrences();
  }

  Future<void> _loadOccurrences() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final data =
          await ApiClient.instance.getOccurrences(widget.task.id);
      setState(() {
        _occurrences = data.map((json) => Occurrence.fromJson(json)).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to load occurrences: ${e.toString()}')),
        );
      }
    }
  }

  Map<String, List<Occurrence>> _groupByMonth() {
    final groups = <String, List<Occurrence>>{};
    for (final occurrence in _occurrences) {
      final key = DateFormat('MMMM yyyy').format(occurrence.scheduledAt);
      groups.putIfAbsent(key, () => []).add(occurrence);
    }
    return groups;
  }

  Future<void> _editTask() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => RecurringTaskFormScreen(existingTask: widget.task),
      ),
    );
    if (result == true && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _deleteTask() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Task'),
        content: const Text(
            'Delete this recurring task and all future occurrences?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ApiClient.instance.deleteRecurringTask(widget.task.id);
        if (mounted) {
          Navigator.of(context).pop(true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Task deleted')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete: ${e.toString()}')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final grouped = _groupByMonth();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.task.title),
            RRuleDisplay(
              rrule: widget.task.rrule,
              compact: true,
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _editTask,
            icon: const Icon(Icons.edit),
            tooltip: 'Edit',
          ),
          IconButton(
            onPressed: _deleteTask,
            icon: const Icon(Icons.delete),
            tooltip: 'Delete',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _occurrences.isEmpty
              ? const Center(
                  child: Text('No occurrences generated yet'),
                )
              : RefreshIndicator(
                  onRefresh: _loadOccurrences,
                  child: ListView(
                    padding: const EdgeInsets.all(16.0),
                    children: [
                      // Task info card
                      Card(
                        elevation: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Task Details',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 12),
                              if (widget.task.description != null) ...[
                                Text(widget.task.description!),
                                const SizedBox(height: 12),
                              ],
                              Row(
                                children: [
                                  const Icon(Icons.star, size: 16, color: Colors.amber),
                                  const SizedBox(width: 4),
                                  Text('${widget.task.points} points'),
                                  const SizedBox(width: 16),
                                  const Icon(Icons.timer, size: 16),
                                  const SizedBox(width: 4),
                                  Text('${widget.task.estimatedMinutes} min'),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  Chip(
                                    label: Text(widget.task.category.displayName),
                                    avatar: Icon(widget.task.category.icon, size: 16),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  Chip(
                                    label: Text(widget.task.rotationStrategy.displayName),
                                    avatar: Icon(widget.task.rotationStrategy.icon, size: 16),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  if (widget.task.photoRequired)
                                    const Chip(
                                      label: Text('Photo required'),
                                      avatar: Icon(Icons.camera_alt, size: 16),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                  if (widget.task.parentApproval)
                                    const Chip(
                                      label: Text('Approval needed'),
                                      avatar: Icon(Icons.verified_user, size: 16),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Occurrences grouped by month
                      ...grouped.entries.map((entry) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8.0),
                              child: Text(
                                entry.key,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ),
                            ...entry.value.map((occurrence) {
                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor:
                                        occurrence.status.color.withValues(alpha: 0.2),
                                    child: Text(
                                      occurrence.assignedToName?[0] ?? '?',
                                      style: TextStyle(
                                          color: occurrence.status.color),
                                    ),
                                  ),
                                  title: Text(occurrence.assignedToName ?? 'Unassigned'),
                                  subtitle: Text(
                                    DateFormat('EEE, MMM d, y')
                                        .format(occurrence.scheduledAt),
                                  ),
                                  trailing: Chip(
                                    label: Text(occurrence.status.displayName),
                                    backgroundColor: occurrence.status.color,
                                    labelStyle:
                                        const TextStyle(color: Colors.white),
                                  ),
                                ),
                              );
                            }).toList(),
                          ],
                        );
                      }).toList(),
                    ],
                  ),
                ),
    );
  }
}
