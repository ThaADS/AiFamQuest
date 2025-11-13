import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'calendar_provider.dart';
import '../../services/local_storage.dart';

/// Event detail screen with access control
class EventDetailScreen extends ConsumerWidget {
  final String eventId;

  const EventDetailScreen({super.key, required this.eventId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final calendarState = ref.watch(calendarProvider);
    final event = calendarState.events.firstWhere(
      (e) => e.id == eventId,
      orElse: () => throw Exception('Event not found'),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Event Details'),
        centerTitle: true,
        actions: [
          // Edit button (check permissions)
          FutureBuilder<bool>(
            future: _canEdit(context),
            builder: (context, snapshot) {
              if (snapshot.data == true) {
                return IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () {
                    Navigator.pushNamed(
                      context,
                      '/calendar/event/edit',
                      arguments: event,
                    );
                  },
                  tooltip: 'Edit',
                );
              }
              return const SizedBox.shrink();
            },
          ),
          // Delete button (check permissions)
          FutureBuilder<bool>(
            future: _canDelete(context),
            builder: (context, snapshot) {
              if (snapshot.data == true) {
                return IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () => _confirmDelete(context, ref, event),
                  tooltip: 'Delete',
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title section
            _buildSectionCard(
              context,
              icon: _getCategoryIcon(event.category),
              iconColor: _getCategoryColor(event.category),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildCategoryChip(context, event.category),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Time section
            _buildSectionCard(
              context,
              icon: Icons.schedule,
              iconColor: colorScheme.primary,
              child: Column(
                children: [
                  _buildInfoRow(
                    context,
                    'Start',
                    _formatDateTime(event.startTime),
                    Icons.play_arrow,
                  ),
                  const Divider(height: 24),
                  _buildInfoRow(
                    context,
                    'End',
                    _formatDateTime(event.endTime),
                    Icons.stop,
                  ),
                  if (event.isAllDay) ...[
                    const Divider(height: 24),
                    _buildInfoRow(
                      context,
                      'All Day Event',
                      'Yes',
                      Icons.all_inclusive,
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Description section
            if (event.description != null)
              _buildSectionCard(
                context,
                icon: Icons.description,
                iconColor: colorScheme.secondary,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Description',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      event.description!,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 16),

            // Attendees section
            if (event.attendees.isNotEmpty)
              _buildSectionCard(
                context,
                icon: Icons.people,
                iconColor: colorScheme.tertiary,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Attendees (${event.attendees.length})',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: event.attendees.map((userId) {
                        return Chip(
                          avatar: CircleAvatar(
                            backgroundColor: colorScheme.primaryContainer,
                            child: Text(
                              userId[0].toUpperCase(),
                              style: TextStyle(
                                color: colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                          label: Text(userId), // TODO: Load user name
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 16),

            // Recurrence section
            if (event.recurrence != null)
              _buildSectionCard(
                context,
                icon: Icons.repeat,
                iconColor: colorScheme.secondary,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Recurrence',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      event.recurrence!.getDescription(),
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 16),

            // Metadata section
            _buildSectionCard(
              context,
              icon: Icons.info_outline,
              iconColor: colorScheme.outline,
              child: Column(
                children: [
                  _buildInfoRow(
                    context,
                    'Created by',
                    event.lastModifiedBy,
                    Icons.person,
                  ),
                  const Divider(height: 24),
                  _buildInfoRow(
                    context,
                    'Last updated',
                    DateFormat('MMM d, yyyy HH:mm').format(event.updatedAt),
                    Icons.update,
                  ),
                  if (event.isDirty) ...[
                    const Divider(height: 24),
                    _buildInfoRow(
                      context,
                      'Sync status',
                      'Pending sync',
                      Icons.sync,
                      valueColor: colorScheme.tertiary,
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 80), // Space for FAB
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required Widget child,
  }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: iconColor),
            ),
            const SizedBox(width: 16),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    BuildContext context,
    String label,
    String value,
    IconData icon, {
    Color? valueColor,
  }) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: valueColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryChip(BuildContext context, String category) {
    final categoryColor = _getCategoryColor(category);
    return Chip(
      avatar: Icon(_getCategoryIcon(category), size: 16, color: categoryColor),
      label: Text(category.toUpperCase()),
      backgroundColor: categoryColor.withValues(alpha: 0.1),
      labelStyle: TextStyle(
        color: categoryColor,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return DateFormat('EEEE, MMMM d, yyyy \'at\' HH:mm').format(dateTime);
  }

  Future<bool> _canEdit(BuildContext context) async {
    // Check if user is parent or creator
    final user = await LocalStorage.instance.getCurrentUser();
    if (user == null) return false;
    final role = user['role'] as String?;
    return role == 'parent'; // TODO: Also check if user is creator
  }

  Future<bool> _canDelete(BuildContext context) async {
    // Check if user is parent or creator
    final user = await LocalStorage.instance.getCurrentUser();
    if (user == null) return false;
    final role = user['role'] as String?;
    return role == 'parent'; // TODO: Also check if user is creator
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    CalendarEvent event,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Event'),
        content: Text('Are you sure you want to delete "${event.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await ref.read(calendarProvider.notifier).deleteEvent(event.id);
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Event deleted')),
        );
      }
    }
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'school':
        return Colors.blue;
      case 'sport':
        return Colors.green;
      case 'appointment':
        return Colors.orange;
      case 'family':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'school':
        return Icons.school;
      case 'sport':
        return Icons.sports_soccer;
      case 'appointment':
        return Icons.event;
      case 'family':
        return Icons.family_restroom;
      default:
        return Icons.event_note;
    }
  }
}
