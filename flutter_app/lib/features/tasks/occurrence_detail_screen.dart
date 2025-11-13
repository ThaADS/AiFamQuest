/// Occurrence detail screen
///
/// Shows all generated occurrences of a recurring task

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/recurring_task_models.dart';
import '../../api/client.dart';

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

  @override
  Widget build(BuildContext context) {
    final grouped = _groupByMonth();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.task.title),
            Text(
              widget.task.humanReadablePattern,
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
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
                    children: grouped.entries.map((entry) {
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
                  ),
                ),
    );
  }
}
