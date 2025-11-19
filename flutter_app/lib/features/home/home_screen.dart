import 'package:flutter/material.dart';
import '../../widgets/draggable_grid.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/offline_indicator.dart';
import '../../widgets/sync_status_widget.dart';

/// Home screen with draggable grid layout
/// - iPhone-style grid with customizable layout
/// - Tap to navigate to features
/// - Long-press to enter edit mode
/// - Drag to reorder icons
/// - Offline-first with sync status indicator
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(),
      body: OfflineIndicator(
        child: Stack(
          children: [
            const DraggableGrid(),
            // Sync status indicator in top-right corner
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              right: 16,
              child: const SyncStatusWidget(showLabel: false),
            ),
          ],
        ),
      ),
    );
  }
}
