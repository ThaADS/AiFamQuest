/// Task Pool Screen - Claimable Tasks
///
/// Shows all claimable tasks that users can claim and complete
/// Includes claim/release functionality with TTL countdown

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/task_provider.dart';
import '../../core/app_logger.dart';
import 'dart:async';

class TaskPoolScreen extends ConsumerStatefulWidget {
  const TaskPoolScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<TaskPoolScreen> createState() => _TaskPoolScreenState();
}

class _TaskPoolScreenState extends ConsumerState<TaskPoolScreen> {
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    // Update countdown every second
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _claimTask(Task task, String userId) async {
    try {
      await ref.read(taskProvider.notifier).claimTask(task.id, userId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Claimed "${task.title}"! Complete it within 30 minutes'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      AppLogger.error('[TaskPool] Claim failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to claim task: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _releaseTask(Task task) async {
    try {
      await ref.read(taskProvider.notifier).releaseTask(task.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Task released back to pool'),
            backgroundColor: Colors.blue,
          ),
        );
      }
    } catch (e) {
      AppLogger.error('[TaskPool] Release failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to release task: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatTimeRemaining(DateTime? claimExpiry) {
    if (claimExpiry == null) return '';

    final now = DateTime.now();
    if (claimExpiry.isBefore(now)) return 'Expired';

    final diff = claimExpiry.difference(now);
    final minutes = diff.inMinutes;
    final seconds = diff.inSeconds % 60;

    return '${minutes}m ${seconds}s';
  }

  @override
  Widget build(BuildContext context) {
    final taskState = ref.watch(taskProvider);

    // Get current user ID from state (placeholder - get from auth provider)
    const currentUserId = 'current-user-id'; // TODO: Get from auth provider

    // Filter for claimable tasks
    final claimableTasks = taskState.tasks.where((task) {
      if (!task.claimable) return false;
      if (task.status != TaskStatus.open) return false;

      // Show if unclaimed OR claimed by current user
      return task.claimedBy == null || task.claimedBy == currentUserId;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Task Pool'),
            Text(
              '${claimableTasks.length} available tasks',
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
      body: taskState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : claimableTasks.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inbox, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text('No tasks in the pool',
                          style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 8),
                      const Text('Check back later for new tasks!'),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () async {
                    await ref.read(taskProvider.notifier).fetchTasks();
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: claimableTasks.length,
                    itemBuilder: (context, index) {
                      final task = claimableTasks[index];
                      final isClaimed = task.claimedBy != null;
                      final isClaimedByMe = task.claimedBy == currentUserId;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        elevation: isClaimed ? 0 : 2,
                        color: isClaimed
                            ? Colors.grey[200]
                            : null,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    _getCategoryIcon(task.category),
                                    color: isClaimed ? Colors.grey : _getCategoryColor(task.category),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      task.title,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            decoration: isClaimed && !isClaimedByMe
                                                ? TextDecoration.lineThrough
                                                : null,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                              if (task.description != null) ...[
                                const SizedBox(height: 8),
                                Text(
                                  task.description!,
                                  style: TextStyle(
                                    color: isClaimed ? Colors.grey : null,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  const Icon(Icons.star, size: 16, color: Colors.amber),
                                  const SizedBox(width: 4),
                                  Text('${task.points} points'),
                                  const SizedBox(width: 16),
                                  const Icon(Icons.timer, size: 16),
                                  const SizedBox(width: 4),
                                  Text('${task.estimatedMinutes} min'),
                                ],
                              ),
                              if (task.photoRequired || task.parentApproval) ...[
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    if (task.photoRequired)
                                      const Chip(
                                        label: Text('Photo required'),
                                        avatar: Icon(Icons.camera_alt, size: 16),
                                        visualDensity: VisualDensity.compact,
                                      ),
                                    if (task.parentApproval)
                                      const Chip(
                                        label: Text('Approval needed'),
                                        avatar: Icon(Icons.verified_user, size: 16),
                                        visualDensity: VisualDensity.compact,
                                      ),
                                  ],
                                ),
                              ],
                              const SizedBox(height: 12),
                              // Action buttons
                              if (isClaimed && isClaimedByMe) ...[
                                // Claimed by current user - show countdown and release
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.orange[100],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(Icons.timer, color: Colors.orange),
                                          const SizedBox(width: 8),
                                          Text(
                                            'Time remaining: ${_formatTimeRemaining(task.claimExpiry)}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.orange,
                                            ),
                                          ),
                                        ],
                                      ),
                                      TextButton.icon(
                                        onPressed: () => _releaseTask(task),
                                        icon: const Icon(Icons.undo),
                                        label: const Text('Release'),
                                      ),
                                    ],
                                  ),
                                ),
                              ] else if (isClaimed && !isClaimedByMe) ...[
                                // Claimed by someone else
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[300],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Row(
                                    children: [
                                      Icon(Icons.lock, color: Colors.grey),
                                      SizedBox(width: 8),
                                      Text(
                                        'Claimed by another user',
                                        style: TextStyle(color: Colors.grey),
                                      ),
                                    ],
                                  ),
                                ),
                              ] else ...[
                                // Available to claim
                                SizedBox(
                                  width: double.infinity,
                                  child: FilledButton.icon(
                                    onPressed: () => _claimTask(task, currentUserId),
                                    icon: const Icon(Icons.touch_app),
                                    label: const Text('Claim This Task'),
                                    style: FilledButton.styleFrom(
                                      padding: const EdgeInsets.all(16),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
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
        return Icons.task;
    }
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'cleaning':
        return Colors.blue;
      case 'care':
        return Colors.pink;
      case 'pet':
        return Colors.brown;
      case 'homework':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }
}
