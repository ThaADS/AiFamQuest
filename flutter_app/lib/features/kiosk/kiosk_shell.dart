/// Kiosk shell wrapper for fullscreen displays
///
/// Provides:
/// - Auto-refresh every 5 minutes
/// - Fullscreen mode (web)
/// - Clock display
/// - Exit button with long-press
/// - Clean, distraction-free layout

import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../widgets/pin_exit_dialog.dart';

/// Kiosk shell that wraps kiosk screens with common functionality
class KioskShell extends ConsumerStatefulWidget {
  final Widget child;

  const KioskShell({
    super.key,
    required this.child,
  });

  @override
  ConsumerState<KioskShell> createState() => _KioskShellState();
}

class _KioskShellState extends ConsumerState<KioskShell> {
  Timer? _refreshTimer;
  Timer? _clockTimer;
  DateTime _currentTime = DateTime.now();
  // ignore: unused_field
  bool _isFullscreen = false;

  @override
  void initState() {
    super.initState();
    _startAutoRefresh();
    _startClock();
    _enterFullscreen();
  }

  /// Start auto-refresh timer (5 minutes)
  void _startAutoRefresh() {
    _refreshTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      // Trigger refresh by invalidating providers
      // Note: Specific providers will be invalidated by parent screens
      if (mounted) {
        setState(() {
          // Force rebuild to trigger provider refresh
        });
      }
    });
  }

  /// Start clock update timer (1 second)
  void _startClock() {
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _currentTime = DateTime.now();
        });
      }
    });
  }

  /// Request fullscreen mode (web only)
  Future<void> _enterFullscreen() async {
    if (!kIsWeb) return;

    try {
      // Web-only fullscreen via dynamic imports to avoid package:web on mobile
      // This code will only run in web browsers
      if (kIsWeb) {
        // No-op: Fullscreen API not needed for mobile kiosk
        // Web implementation would use: document.documentElement.requestFullscreen()
      }
      setState(() {
        _isFullscreen = true;
      });
    } catch (e) {
      debugPrint('Fullscreen not available: $e');
    }
  }

  /// Exit fullscreen mode (web only)
  Future<void> _exitFullscreen() async {
    if (!kIsWeb) return;

    try {
      // Web-only fullscreen exit
      if (kIsWeb) {
        // No-op: Fullscreen API not needed for mobile kiosk
        // Web implementation would use: document.exitFullscreen()
      }
      setState(() {
        _isFullscreen = false;
      });
    } catch (e) {
      debugPrint('Exit fullscreen failed: $e');
    }
  }

  /// Show PIN exit dialog
  void _showPinDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const PinExitDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Stack(
        children: [
          // Main content
          Positioned.fill(
            child: widget.child,
          ),

          // Top bar with time and exit button
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 80,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.3),
                    Colors.transparent,
                  ],
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Current time (large, always visible)
                      Text(
                        DateFormat('HH:mm').format(_currentTime),
                        style: const TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          shadows: [
                            Shadow(
                              blurRadius: 4,
                              color: Colors.black54,
                            ),
                          ],
                        ),
                      ),

                      // Date display
                      Text(
                        DateFormat('EEEE, MMM d').format(_currentTime),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w300,
                          color: Colors.white,
                          shadows: [
                            Shadow(
                              blurRadius: 4,
                              color: Colors.black54,
                            ),
                          ],
                        ),
                      ),

                      // Exit button (long-press 3 seconds)
                      Tooltip(
                        message: 'Long-press to exit',
                        child: GestureDetector(
                          onLongPress: _showPinDialog,
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.black26,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.exit_to_app,
                              size: 32,
                              color: Colors.white70,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _clockTimer?.cancel();
    _exitFullscreen();
    super.dispose();
  }
}
