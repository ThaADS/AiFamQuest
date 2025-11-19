/// Real-time Initializer Widget
///
/// Initializes Supabase real-time subscriptions after user login.
/// Should be placed near the root of the widget tree after authentication.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/realtime_service.dart';
import '../providers/task_provider.dart';
import '../features/calendar/calendar_provider.dart';

class RealtimeInitializer extends ConsumerStatefulWidget {
  final String familyId;
  final String userId;
  final Widget child;

  const RealtimeInitializer({
    super.key,
    required this.familyId,
    required this.userId,
    required this.child,
  });

  @override
  ConsumerState<RealtimeInitializer> createState() => _RealtimeInitializerState();
}

class _RealtimeInitializerState extends ConsumerState<RealtimeInitializer> {
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _initializeRealtime();
  }

  Future<void> _initializeRealtime() async {
    if (_initialized) return;

    try {
      // Initialize Supabase realtime subscriptions
      await SupabaseRealtimeService.instance.initialize(widget.familyId);

      // Initialize providers with real-time listeners
      await ref.read(taskProvider.notifier).initialize(
            widget.familyId,
            widget.userId,
          );

      await ref.read(calendarProvider.notifier).initialize();

      setState(() {
        _initialized = true;
      });

      debugPrint('[RealtimeInitializer] Real-time subscriptions initialized');
    } catch (e) {
      debugPrint('[RealtimeInitializer] Initialization error: $e');
    }
  }

  @override
  void dispose() {
    // Cleanup handled by service singleton
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Show connection status indicator
    return Stack(
      children: [
        widget.child,
        // Connection status banner (optional, can be toggled)
        _buildConnectionStatusBanner(),
      ],
    );
  }

  Widget _buildConnectionStatusBanner() {
    final connectionState = ref.watch(
      taskProvider.select((state) => state.isRealtimeConnected),
    );

    // Only show banner when disconnected
    if (connectionState) {
      return const SizedBox.shrink();
    }

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Material(
        color: Colors.orange,
        elevation: 4,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          child: Row(
            children: [
              const Icon(Icons.cloud_off, color: Colors.white, size: 16),
              const SizedBox(width: 8),
              const Text(
                'Real-time sync disconnected',
                style: TextStyle(color: Colors.white, fontSize: 12),
              ),
              const Spacer(),
              TextButton(
                onPressed: () {
                  // Retry connection
                  SupabaseRealtimeService.instance.initialize(widget.familyId);
                },
                child: const Text(
                  'Retry',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
