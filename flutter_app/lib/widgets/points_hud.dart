/// Points HUD Widget
///
/// Persistent display in app bar showing current point balance
/// Features:
/// - Animated counter when points change
/// - Tap to open points detail/stats screen
/// - Material 3 chip design
/// - Compact and visually appealing

import 'package:flutter/material.dart';

class PointsHUD extends StatefulWidget {
  final int points;
  final VoidCallback? onTap;

  const PointsHUD({
    Key? key,
    required this.points,
    this.onTap,
  }) : super(key: key);

  @override
  State<PointsHUD> createState() => _PointsHUDState();
}

class _PointsHUDState extends State<PointsHUD>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  int _previousPoints = 0;

  @override
  void initState() {
    super.initState();
    _previousPoints = widget.points;

    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(PointsHUD oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Animate when points change
    if (widget.points != _previousPoints) {
      _controller.forward().then((_) => _controller.reverse());
      _previousPoints = widget.points;
    }
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

    return ScaleTransition(
      scale: _scaleAnimation,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: colorScheme.primary.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.star,
                  size: 18,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  '${widget.points}',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
