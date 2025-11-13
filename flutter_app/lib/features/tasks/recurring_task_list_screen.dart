/// Recurring task list screen
///
/// Shows all recurring task series with pause/delete actions

import 'package:flutter/material.dart';
import '../../models/recurring_task_models.dart';
import '../../api/client.dart';
import 'recurring_task_form.dart';
import 'occurrence_detail_screen.dart';

class RecurringTaskListScreen extends StatefulWidget {
  const RecurringTaskListScreen({Key? key}) : super(key: key);

  @override
  State<RecurringTaskListScreen> createState() =>
      _RecurringTaskListScreenState();
}

class _RecurringTaskListScreenState extends State<RecurringTaskListScreen> {
  List<RecurringTask> _tasks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final data = await ApiClient.instance.listRecurringTasks();
      setState(() {
        _tasks = data.map((json) => RecurringTask.fromJson(json)).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load tasks: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _pauseTask(RecurringTask task) async {
    try {
      await ApiClient.instance.pauseRecurringTask(task.id);
      _loadTasks();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Task paused')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pause: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _resumeTask(RecurringTask task) async {
    try {
      await ApiClient.instance.resumeRecurringTask(task.id);
      _loadTasks();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Task resumed')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to resume: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _deleteTask(RecurringTask task) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Recurring Task'),
        content: const Text(
            'Are you sure? This will delete all future occurrences.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ApiClient.instance.deleteRecurringTask(task.id);
        _loadTasks();
        if (mounted) {
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recurring Tasks'),
        actions: [
          IconButton(
            onPressed: _loadTasks,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _tasks.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.repeat, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text('No recurring tasks yet',
                          style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 8),
                      const Text('Create one to automate task scheduling'),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadTasks,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16.0),
                    itemCount: _tasks.length,
                    itemBuilder: (context, index) {
                      final task = _tasks[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        child: InkWell(
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) =>
                                    OccurrenceDetailScreen(task: task),
                              ),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(task.category.icon,
                                        color: task.category.color),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        task.title,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                                fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    if (task.isPaused)
                                      const Chip(
                                        label: Text('Paused'),
                                        backgroundColor: Colors.orange,
                                        labelStyle: TextStyle(
                                            color: Colors.white, fontSize: 12),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Icon(Icons.schedule, size: 16),
                                    const SizedBox(width: 4),
                                    Text(task.humanReadablePattern),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(task.rotationStrategy.icon, size: 16),
                                    const SizedBox(width: 4),
                                    Text(task.rotationStrategy.displayName),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.star,
                                            size: 16, color: Colors.amber),
                                        const SizedBox(width: 4),
                                        Text('${task.points} pts'),
                                        const SizedBox(width: 12),
                                        if (task.photoRequired)
                                          const Icon(Icons.camera_alt,
                                              size: 16),
                                        if (task.parentApproval)
                                          const Icon(Icons.verified_user,
                                              size: 16),
                                      ],
                                    ),
                                    Row(
                                      children: [
                                        IconButton(
                                          onPressed: () async {
                                            final result =
                                                await Navigator.of(context)
                                                    .push(
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    RecurringTaskFormScreen(
                                                        existingTask: task),
                                              ),
                                            );
                                            if (result == true) _loadTasks();
                                          },
                                          icon: const Icon(Icons.edit),
                                          tooltip: 'Edit',
                                        ),
                                        IconButton(
                                          onPressed: () => task.isPaused
                                              ? _resumeTask(task)
                                              : _pauseTask(task),
                                          icon: Icon(task.isPaused
                                              ? Icons.play_arrow
                                              : Icons.pause),
                                          tooltip: task.isPaused
                                              ? 'Resume'
                                              : 'Pause',
                                        ),
                                        IconButton(
                                          onPressed: () => _deleteTask(task),
                                          icon: const Icon(Icons.delete),
                                          tooltip: 'Delete',
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const RecurringTaskFormScreen(),
            ),
          );
          if (result == true) _loadTasks();
        },
        icon: const Icon(Icons.add),
        label: const Text('New Task'),
      ),
    );
  }
}
