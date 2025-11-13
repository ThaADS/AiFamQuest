/// Streak Display Widget
///
/// Shows current streak with fire emoji
/// Features:
/// - Fire emoji + streak count
/// - "X day streak!" text
/// - Visual indicator if streak at risk
/// - Tap to open streak detail
/// - Animated fire when streak increases

import 'package:flutter/material.dart';
import '../models/gamification_models.dart';

class StreakWidget extends StatefulWidget {
  final UserStreak streak;
  final VoidCallback? onTap;
  final bool compact;

  const StreakWidget({
    Key? key,
    required this.streak,
    this.onTap,
    this.compact = false,
  }) : super(key: key);

  @override
  State<StreakWidget> createState() => _StreakWidgetState();
}

class _StreakWidgetState extends State<StreakWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  int _previousStreak = 0;

  @override
  void initState() {
    super.initState();
    _previousStreak = widget.streak.current;

    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );
  }

  @override
  void didUpdateWidget(StreakWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Animate when streak increases
    if (widget.streak.current > _previousStreak) {
      _controller.forward().then((_) => _controller.reverse());
    }
    _previousStreak = widget.streak.current;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (widget.compact) {
      return _buildCompactView(theme, colorScheme);
    }

    return _buildFullView(theme, colorScheme);
  }

  Widget _buildCompactView(ThemeData theme, ColorScheme colorScheme) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: widget.streak.isAtRisk
                ? colorScheme.errorContainer
                : Colors.orange.shade100,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: widget.streak.isAtRisk
                  ? colorScheme.error.withValues(alpha: 0.3)
                  : Colors.orange.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ScaleTransition(
                scale: _scaleAnimation,
                child: const Text(
                  '🔥',
                  style: TextStyle(fontSize: 16),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '${widget.streak.current}',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: widget.streak.isAtRisk
                      ? colorScheme.error
                      : Colors.orange.shade900,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFullView(ThemeData theme, ColorScheme colorScheme) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: widget.streak.isAtRisk
                ? colorScheme.errorContainer
                : Colors.orange.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: widget.streak.isAtRisk
                  ? colorScheme.error.withValues(alpha: 0.3)
                  : Colors.orange.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ScaleTransition(
                    scale: _scaleAnimation,
                    child: const Text(
                      '🔥',
                      style: TextStyle(fontSize: 32),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${widget.streak.current} day streak!',
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: widget.streak.isAtRisk
                              ? colorScheme.error
                              : Colors.orange.shade900,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (widget.streak.isAtRisk)
                        Text(
                          'Complete a task today!',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.error,
                          ),
                        )
                      else if (widget.streak.longest > widget.streak.current)
                        Text(
                          'Longest: ${widget.streak.longest} days',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.orange.shade700,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              if (widget.streak.isAtRisk) ...[
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: 0.3,
                  backgroundColor: colorScheme.error.withValues(alpha: 0.2),
                  color: colorScheme.error,
                ),
                const SizedBox(height: 4),
                Text(
                  'Streak at risk! Complete a task to keep it alive.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.error,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
