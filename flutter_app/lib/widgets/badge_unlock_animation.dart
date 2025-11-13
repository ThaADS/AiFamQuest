/// Badge Unlock Animation
///
/// Animated dialog for new badge unlocks
/// Features:
/// - Badge icon scales in with bounce
/// - Sparkle/confetti effect
/// - Badge name and description
/// - "Awesome!" or "Well done!" message
/// - Auto-dismiss after 3 seconds or tap
/// - Celebration animation

import 'package:flutter/material.dart';
import '../models/gamification_models.dart';

class BadgeUnlockAnimation extends StatefulWidget {
  final UserBadge badge;
  final VoidCallback? onDismiss;

  const BadgeUnlockAnimation({
    Key? key,
    required this.badge,
    this.onDismiss,
  }) : super(key: key);

  @override
  State<BadgeUnlockAnimation> createState() => _BadgeUnlockAnimationState();
}

class _BadgeUnlockAnimationState extends State<BadgeUnlockAnimation>
    with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late AnimationController _sparkleController;
  late AnimationController _fadeController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _sparkleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    // Scale animation for badge
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _scaleAnimation = CurvedAnimation(
      parent: _scaleController,
      curve: Curves.elasticOut,
    );

    // Sparkle animation
    _sparkleController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _sparkleAnimation = CurvedAnimation(
      parent: _sparkleController,
      curve: Curves.easeInOut,
    );

    // Fade animation for text
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    );

    // Start animations
    _scaleController.forward();
    _sparkleController.repeat();
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _fadeController.forward();
    });

    // Auto-dismiss after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) _dismiss();
    });
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _sparkleController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _dismiss() {
    Navigator.pop(context);
    widget.onDismiss?.call();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return GestureDetector(
      onTap: _dismiss,
      child: Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Stack(
          children: [
            // Sparkle effect background
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _sparkleController,
                builder: (context, child) {
                  return CustomPaint(
                    painter: SparklePainter(
                      _sparkleAnimation.value,
                      widget.badge.color,
                    ),
                  );
                },
              ),
            ),

            // Content card
            Center(
              child: Container(
                margin: const EdgeInsets.all(24),
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: widget.badge.color.withValues(alpha: 0.3),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Badge icon with scale animation
                    ScaleTransition(
                      scale: _scaleAnimation,
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: widget.badge.color.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          widget.badge.icon,
                          size: 80,
                          color: widget.badge.color,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Celebration message
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: Column(
                        children: [
                          Text(
                            _getCelebrationMessage(),
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.primary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Badge Unlocked!',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),

                          // Badge name
                          Text(
                            widget.badge.name,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),

                          // Badge description
                          Text(
                            widget.badge.description,
                            style: theme.textTheme.bodyMedium,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),

                          // Tap to dismiss hint
                          Text(
                            'Tap to continue',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getCelebrationMessage() {
    final messages = [
      'Awesome!',
      'Well Done!',
      'Amazing!',
      'Fantastic!',
      'Incredible!',
      'Outstanding!',
    ];
    return messages[widget.badge.code.hashCode % messages.length];
  }
}

/// Sparkle painter for celebration effect
class SparklePainter extends CustomPainter {
  final double progress;
  final Color color;

  SparklePainter(this.progress, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.6)
      ..style = PaintingStyle.fill;

    final centerX = size.width / 2;
    final centerY = size.height / 2;

    // Draw sparkle particles
    for (int i = 0; i < 20; i++) {
      final angle = (6.28 / 20) * i;
      final distance = 100 * progress;
      final x = centerX + distance * (angle.cos);
      final y = centerY + distance * (angle.sin);

      // Fade out as they move away
      final opacity = (1 - progress).clamp(0.0, 1.0);
      paint.color = color.withOpacity(opacity * 0.6);

      // Draw sparkle star
      _drawStar(canvas, Offset(x, y), 6 * (1 - progress * 0.5), paint);
    }
  }

  void _drawStar(Canvas canvas, Offset center, double size, Paint paint) {
    final path = Path();
    for (int i = 0; i < 5; i++) {
      final angle = (6.28 / 5) * i - 1.57;
      final x = center.dx + size * angle.cos;
      final y = center.dy + size * angle.sin;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(SparklePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

// Extension for trigonometric functions
extension on double {
  double get sin => this * 0.017453292519943295;
  double get cos => (this - 90) * 0.017453292519943295;
}
