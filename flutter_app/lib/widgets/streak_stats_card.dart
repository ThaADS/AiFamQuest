/// Streak Stats Card Widget
///
/// Comprehensive streak statistics for profile screen
/// Features:
/// - Current streak display
/// - Longest streak achieved
/// - Total days with tasks
/// - Streak save count
/// - Tap to view history

import 'package:flutter/material.dart';
import '../models/gamification_models.dart';
import '../features/gamification/streak_history_screen.dart';

class StreakStatsCard extends StatelessWidget {
  final String userId;
  final UserStreak streak;
  final int totalDaysWithTasks;
  final int streakSaveCount;

  const StreakStatsCard({
    Key? key,
    required this.userId,
    required this.streak,
    this.totalDaysWithTasks = 0,
    this.streakSaveCount = 0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 2,
      child: InkWell(
        onTap: () => _navigateToHistory(context),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Streak Statistics',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Current and Longest Streak
              Row(
                children: [
                  Expanded(
                    child: _buildStatItem(
                      context: context,
                      icon: Icons.local_fire_department,
                      label: 'Current Streak',
                      value: '${streak.current}',
                      subtitle: 'days',
                      color: Colors.orange,
                      isHighlight: true,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildStatItem(
                      context: context,
                      icon: Icons.emoji_events,
                      label: 'Longest Streak',
                      value: '${streak.longest}',
                      subtitle: 'days',
                      color: Colors.amber,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Total Days and Saves
              Row(
                children: [
                  Expanded(
                    child: _buildStatItem(
                      context: context,
                      icon: Icons.calendar_today,
                      label: 'Active Days',
                      value: '$totalDaysWithTasks',
                      subtitle: 'with tasks',
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildStatItem(
                      context: context,
                      icon: Icons.shield,
                      label: 'Streak Saves',
                      value: '$streakSaveCount',
                      subtitle: 'rescues',
                      color: Colors.green,
                    ),
                  ),
                ],
              ),

              // At risk warning
              if (streak.isAtRisk) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.warning_amber,
                        color: colorScheme.error,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Complete a task today to keep your streak alive!',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.error,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // View history link
              const SizedBox(height: 12),
              Center(
                child: TextButton.icon(
                  onPressed: () => _navigateToHistory(context),
                  icon: const Icon(Icons.timeline, size: 18),
                  label: const Text('View Full History'),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String value,
    required String subtitle,
    required Color color,
    bool isHighlight = false,
  }) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isHighlight
            ? color.withValues(alpha: 0.1)
            : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: isHighlight
            ? Border.all(color: color.withValues(alpha: 0.3), width: 2)
            : null,
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: theme.textTheme.bodySmall,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  void _navigateToHistory(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StreakHistoryScreen(userId: userId),
      ),
    );
  }
}
