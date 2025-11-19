/// Streak Celebration Widget
///
/// Animated celebration overlay for streak milestones
/// Features:
/// - Confetti animation using custom painter
/// - Fire emoji animation
/// - Milestone badges (7, 30, 100 days)
/// - Share achievement option
/// - Auto-dismiss after animation

import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:share_plus/share_plus.dart';

class StreakCelebration extends StatefulWidget {
  final int streakDays;
  final VoidCallback? onDismiss;

  const StreakCelebration({
    Key? key,
    required this.streakDays,
    this.onDismiss,
  }) : super(key: key);

  @override
  State<StreakCelebration> createState() => _StreakCelebrationState();

  /// Show celebration as overlay
  static void show(BuildContext context, int streakDays) {
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black54,
      builder: (context) => StreakCelebration(
        streakDays: streakDays,
        onDismiss: () => Navigator.pop(context),
      ),
    );
  }
}

class _StreakCelebrationState extends State<StreakCelebration>
    with TickerProviderStateMixin {
  late AnimationController _confettiController;
  late AnimationController _scaleController;
  late AnimationController _rotateController;

  late Animation<double> _scaleAnimation;
  late Animation<double> _rotateAnimation;

  @override
  void initState() {
    super.initState();

    // Confetti animation (3 seconds)
    _confettiController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..forward();

    // Scale animation (bounce effect)
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _scaleAnimation = CurvedAnimation(
      parent: _scaleController,
      curve: Curves.elasticOut,
    );

    _scaleController.forward();

    // Rotate animation (fire emoji wiggle)
    _rotateController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    )..repeat(reverse: true);

    _rotateAnimation = Tween<double>(begin: -0.1, end: 0.1).animate(
      CurvedAnimation(parent: _rotateController, curve: Curves.easeInOut),
    );

    // Auto-dismiss after 5 seconds
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted && widget.onDismiss != null) {
        widget.onDismiss!();
      }
    });
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _scaleController.dispose();
    _rotateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // final colorScheme = theme.colorScheme;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Stack(
        children: [
          // Confetti background
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _confettiController,
              builder: (context, child) {
                return CustomPaint(
                  painter: ConfettiPainter(
                    progress: _confettiController.value,
                  ),
                );
              },
            ),
          ),

          // Celebration card
          Center(
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 320),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.orange.shade400,
                      Colors.deepOrange.shade600,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.orange.withValues(alpha: 0.5),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Animated fire emoji
                    AnimatedBuilder(
                      animation: _rotateAnimation,
                      builder: (context, child) {
                        return Transform.rotate(
                          angle: _rotateAnimation.value,
                          child: child,
                        );
                      },
                      child: Text(
                        _getFireEmoji(widget.streakDays),
                        style: const TextStyle(fontSize: 80),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Title
                    Text(
                      _getTitle(widget.streakDays),
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),

                    // Subtitle
                    Text(
                      '${widget.streakDays} days in a row!',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),

                    // Message
                    Text(
                      _getMessage(widget.streakDays),
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),

                    // Action buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Share button
                        TextButton.icon(
                          onPressed: () => _shareAchievement(),
                          icon: const Icon(Icons.share, color: Colors.white),
                          label: Text(
                            'Share',
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: Colors.white,
                            ),
                          ),
                          style: TextButton.styleFrom(
                            backgroundColor: Colors.white.withValues(alpha: 0.2),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Close button
                        FilledButton(
                          onPressed: widget.onDismiss,
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.orange.shade700,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                          ),
                          child: const Text('Awesome!'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getFireEmoji(int days) {
    if (days >= 100) return '🔥🔥🔥';
    if (days >= 30) return '🔥🔥';
    return '🔥';
  }

  String _getTitle(int days) {
    if (days >= 100) return 'LEGENDARY!';
    if (days >= 30) return 'Month Streak!';
    if (days >= 7) return 'Week Streak!';
    return 'Streak Milestone!';
  }

  String _getMessage(int days) {
    if (days >= 100) {
      return 'You\'re a FamQuest champion! 100 days of consistency!';
    } else if (days >= 30) {
      return 'Incredible dedication! Keep the momentum going!';
    } else if (days >= 7) {
      return 'Amazing! You\'ve built a solid habit!';
    } else if (days >= 3) {
      return 'You\'re on a roll! Keep it up!';
    } else {
      return 'Great start! Let\'s keep this going!';
    }
  }

  void _shareAchievement() {
    Share.share(
      '🔥 I just reached a ${widget.streakDays} day streak in FamQuest! '
      'Staying consistent with my family tasks! 💪 #FamQuest #StreakMaster',
      subject: 'FamQuest Streak Achievement',
    );
  }
}

/// Custom painter for confetti animation
class ConfettiPainter extends CustomPainter {
  final double progress;
  final math.Random random = math.Random(42); // Fixed seed for consistency

  ConfettiPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    const confettiCount = 50;
    const colors = [
      Colors.red,
      Colors.blue,
      Colors.green,
      Colors.yellow,
      Colors.purple,
      Colors.orange,
      Colors.pink,
      Colors.teal,
    ];

    for (int i = 0; i < confettiCount; i++) {
      // Deterministic position based on index
      final startX = (i * 37) % size.width.toInt();
      const startY = -20.0;

      // Calculate current position based on progress
      final x = startX + (random.nextDouble() - 0.5) * 100 * progress;
      final y = startY + size.height * progress + (i % 3) * 50;

      // Skip if offscreen
      if (y > size.height) continue;

      // Random color
      final color = colors[i % colors.length].withValues(alpha: 1.0 - progress * 0.3);

      // Random rotation
      final rotation = (i * 0.5 + progress * math.pi * 4) % (math.pi * 2);

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(rotation);

      // Draw confetti piece (rectangle or circle)
      final paint = Paint()..color = color;

      if (i % 2 == 0) {
        // Rectangle
        canvas.drawRect(
          const Rect.fromLTWH(-5, -10, 10, 20),
          paint,
        );
      } else {
        // Circle
        canvas.drawCircle(Offset.zero, 5, paint);
      }

      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(ConfettiPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
