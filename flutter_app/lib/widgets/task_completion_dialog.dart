/// Task Completion Dialog
///
/// Shown after completing a task with celebration
/// Features:
/// - "Great job!" message
/// - Points earned breakdown (base + bonus)
/// - Streak bonus if applicable
/// - New streak status
/// - New badges (if any) with animation
/// - "Continue" button
/// - Confetti animation

import 'package:flutter/material.dart';
import '../models/gamification_models.dart';

class TaskCompletionDialog extends StatefulWidget {
  final int pointsEarned;
  final int basePoints;
  final int streakBonus;
  final int newStreak;
  final List<UserBadge> newBadges;
  final VoidCallback? onContinue;

  const TaskCompletionDialog({
    Key? key,
    required this.pointsEarned,
    required this.basePoints,
    this.streakBonus = 0,
    this.newStreak = 0,
    this.newBadges = const [],
    this.onContinue,
  }) : super(key: key);

  @override
  State<TaskCompletionDialog> createState() => _TaskCompletionDialogState();
}

class _TaskCompletionDialogState extends State<TaskCompletionDialog>
    with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late AnimationController _confettiController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _confettiController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _scaleAnimation = CurvedAnimation(
      parent: _scaleController,
      curve: Curves.elasticOut,
    );

    _scaleController.forward();
    _confettiController.forward();
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Stack(
        children: [
          // Confetti background
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _confettiController,
              builder: (context, child) {
                return CustomPaint(
                  painter: ConfettiPainter(_confettiController.value),
                );
              },
            ),
          ),

          // Content
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Celebration emoji
                ScaleTransition(
                  scale: _scaleAnimation,
                  child: const Text(
                    '🎉',
                    style: TextStyle(fontSize: 64),
                  ),
                ),
                const SizedBox(height: 16),

                // "Great job!" message
                Text(
                  'Great Job!',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Task completed successfully!',
                  style: theme.textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),

                // Points breakdown
                _buildPointsBreakdown(theme, colorScheme),
                const SizedBox(height: 16),

                // Streak status
                if (widget.newStreak > 0) ...[
                  _buildStreakStatus(theme, colorScheme),
                  const SizedBox(height: 16),
                ],

                // New badges
                if (widget.newBadges.isNotEmpty) ...[
                  _buildNewBadges(theme, colorScheme),
                  const SizedBox(height: 16),
                ],

                // Continue button
                FilledButton(
                  onPressed: () {
                    Navigator.pop(context);
                    widget.onContinue?.call();
                  },
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                  ),
                  child: const Text('Continue'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPointsBreakdown(ThemeData theme, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.primary.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Base Points:',
                style: theme.textTheme.bodyMedium,
              ),
              Text(
                '+${widget.basePoints}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          if (widget.streakBonus > 0) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Text('🔥', style: TextStyle(fontSize: 16)),
                    const SizedBox(width: 4),
                    Text(
                      'Streak Bonus (${widget.newStreak} days):',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
                Text(
                  '+${widget.streakBonus}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: Colors.orange.shade900,
                  ),
                ),
              ],
            ),
          ],
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Points:',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Row(
                children: [
                  Icon(Icons.star, color: Colors.amber.shade700, size: 24),
                  const SizedBox(width: 4),
                  Text(
                    '+${widget.pointsEarned}',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStreakStatus(ThemeData theme, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.orange.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🔥', style: TextStyle(fontSize: 24)),
          const SizedBox(width: 8),
          Text(
            '${widget.newStreak} day streak!',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.orange.shade900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNewBadges(ThemeData theme, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.amber.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.emoji_events, color: Colors.amber.shade700, size: 24),
              const SizedBox(width: 8),
              Text(
                'New Badge${widget.newBadges.length > 1 ? 's' : ''}!',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.amber.shade900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: widget.newBadges.map((badge) {
              return Column(
                children: [
                  Icon(badge.icon, size: 32, color: badge.color),
                  const SizedBox(height: 4),
                  Text(
                    badge.name,
                    style: theme.textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

/// Confetti painter for celebration effect
class ConfettiPainter extends CustomPainter {
  final double progress;

  ConfettiPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    final colors = [
      Colors.red,
      Colors.blue,
      Colors.green,
      Colors.yellow,
      Colors.purple,
      Colors.orange,
    ];

    // Draw confetti pieces
    for (int i = 0; i < 30; i++) {
      final x = (size.width / 30) * i;
      final y = size.height * progress * (1 + (i % 3) * 0.3);
      final rotation = progress * 6.28 * (i % 4);

      paint.color = colors[i % colors.length].withValues(alpha: 0.7);

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(rotation);
      canvas.drawRect(
        const Rect.fromLTWH(-3, -3, 6, 6),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(ConfettiPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
