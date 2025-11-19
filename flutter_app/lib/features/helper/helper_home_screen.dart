import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../api/client.dart';

/// Helper Home Screen - Simplified interface for external helpers
///
/// Features:
/// - View assigned tasks only
/// - Complete tasks with optional photo upload
/// - Limited UI (no family-wide access)
/// - Clear role identification
class HelperHomeScreen extends ConsumerStatefulWidget {
  const HelperHomeScreen({super.key});

  @override
  ConsumerState<HelperHomeScreen> createState() => _HelperHomeScreenState();
}

class _HelperHomeScreenState extends ConsumerState<HelperHomeScreen> {
  bool _isLoading = true;
  List<dynamic> _tasks = [];
  String? _familyName;

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    setState(() => _isLoading = true);

    try {
      final tasks = await ApiClient.instance.getHelperTasks();
      if (mounted) {
        setState(() {
          _tasks = tasks;
          _isLoading = false;
          // Extract family name from first task if available
          _familyName = tasks.isNotEmpty ? tasks[0]['familyName'] ?? 'FamQuest' : 'FamQuest';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load tasks: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_familyName ?? 'FamQuest'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadTasks,
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _handleLogout,
            tooltip: 'Logout',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadTasks,
        child: Column(
          children: [
            _buildHeader(theme),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _tasks.isEmpty
                      ? _buildEmptyState(theme)
                      : _buildTaskList(),
            ),
          ],
        ),
      ),
    );
  }

  /// Build header with role identification
  Widget _buildHeader(ThemeData theme) {
    final todayTasks = _tasks.where((task) {
      return true;
    }).length;

    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outline.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.support_agent,
                      size: 16,
                      color: theme.colorScheme.onPrimary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'External Help',
                      style: TextStyle(
                        color: theme.colorScheme.onPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                DateFormat('EEEE, MMM d').format(DateTime.now()),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Your Tasks',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$todayTasks tasks assigned today',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }

  /// Build task list
  Widget _buildTaskList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: _tasks.length,
      itemBuilder: (context, index) {
        final task = _tasks[index];
        return _buildTaskCard(task);
      },
    );
  }

  /// Build individual task card
  Widget _buildTaskCard(Map<String, dynamic> task) {
    final theme = Theme.of(context);
    final title = task['title'] ?? 'Untitled Task';
    final description = task['description'] ?? '';
    final dueDate = task['dueDate'] != null
        ? DateTime.parse(task['dueDate'])
        : null;
    final points = task['points'] ?? 0;
    final isCompleted = task['status'] == 'completed';

    return Card(
      margin: const EdgeInsets.only(bottom: 12.0),
      elevation: 2,
      child: InkWell(
        onTap: isCompleted ? null : () => _showTaskDetails(task),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Category icon
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _getCategoryIcon(task['category']),
                      color: theme.colorScheme.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            decoration: isCompleted ? TextDecoration.lineThrough : null,
                          ),
                        ),
                        if (description.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            description,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (isCompleted)
                    const Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: 28,
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  if (dueDate != null) ...[
                    Icon(
                      Icons.calendar_today,
                      size: 14,
                      color: _getDueDateColor(dueDate, theme),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      DateFormat('MMM d, h:mm a').format(dueDate),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: _getDueDateColor(dueDate, theme),
                      ),
                    ),
                    const SizedBox(width: 16),
                  ],
                  if (points > 0) ...[
                    const Icon(
                      Icons.stars,
                      size: 14,
                      color: Colors.amber,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '$points pts',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  const Spacer(),
                  if (!isCompleted)
                    FilledButton.icon(
                      onPressed: () => _completeTask(task),
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Complete'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build empty state
  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.task_alt,
            size: 80,
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'No tasks assigned',
            style: theme.textTheme.titleLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Check back later for new assignments',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  /// Get category icon
  IconData _getCategoryIcon(String? category) {
    switch (category?.toLowerCase()) {
      case 'cleaning':
        return Icons.cleaning_services;
      case 'cooking':
        return Icons.restaurant;
      case 'shopping':
        return Icons.shopping_cart;
      case 'laundry':
        return Icons.local_laundry_service;
      case 'outdoor':
        return Icons.yard;
      default:
        return Icons.task;
    }
  }

  /// Get due date color based on urgency
  Color _getDueDateColor(DateTime dueDate, ThemeData theme) {
    final now = DateTime.now();
    final difference = dueDate.difference(now);

    if (difference.isNegative) return Colors.red;
    if (difference.inHours < 2) return Colors.orange;
    return theme.colorScheme.onSurfaceVariant;
  }

  /// Show task details
  void _showTaskDetails(Map<String, dynamic> task) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            padding: const EdgeInsets.all(20),
            child: ListView(
              controller: scrollController,
              children: [
                Text(
                  task['title'] ?? 'Task Details',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 16),
                if (task['description']?.isNotEmpty == true) ...[
                  Text(
                    task['description'],
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 24),
                ],
                FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _completeTask(task);
                  },
                  icon: const Icon(Icons.check),
                  label: const Text('Mark as Complete'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Complete task
  Future<void> _completeTask(Map<String, dynamic> task) async {
    try {
      final taskId = task['id'] as String;

      // Check if photo is required
      final photoRequired = task['photoRequired'] == true;

      if (photoRequired) {
        // Show photo upload dialog
        await _showPhotoUploadDialog(taskId);
      } else {
        // Complete directly
        await ApiClient.instance.completeTask(taskId);

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Task completed!'),
            backgroundColor: Colors.green,
          ),
        );
      }

      // Reload tasks
      _loadTasks();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to complete task: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  /// Show photo upload dialog for task completion
  Future<void> _showPhotoUploadDialog(String taskId) async {
    // For now, just complete without photo
    // TODO: Implement photo picker integration
    await ApiClient.instance.completeTask(taskId);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Task completed!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  /// Handle logout
  void _handleLogout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}
