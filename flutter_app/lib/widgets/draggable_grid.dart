import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/grid_item.dart';
import '../services/grid_layout_service.dart';
import '../core/app_logger.dart';

/// Draggable grid widget with iPhone-style interaction
/// - Tap to navigate
/// - Long-press to enter edit mode with wiggle animation
/// - Drag to reorder
/// - Auto-save layout to database
class DraggableGrid extends StatefulWidget {
  const DraggableGrid({super.key});

  @override
  State<DraggableGrid> createState() => _DraggableGridState();
}

class _DraggableGridState extends State<DraggableGrid>
    with TickerProviderStateMixin {
  List<GridItem> items = [];
  bool isEditMode = false;
  bool isLoading = true;
  int? draggingIndex;

  late AnimationController _wiggleController;

  static const mochaBrown = Color(0xFF6B4423);
  static const lightMocha = Color(0xFFB08968);
  static const cream = Color(0xFFF5EBE0);
  static const darkMocha = Color(0xFF3D2817);

  @override
  void initState() {
    super.initState();
    _wiggleController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _loadLayout();
  }

  @override
  void dispose() {
    _wiggleController.dispose();
    super.dispose();
  }

  Future<void> _loadLayout() async {
    setState(() => isLoading = true);
    try {
      final loadedItems = await GridLayoutService.loadLayout();
      if (mounted) {
        setState(() {
          items = loadedItems;
          isLoading = false;
        });
      }
    } catch (e) {
      AppLogger.debug('[GRID] Error loading: $e');
      if (mounted) {
        setState(() {
          items = DefaultGridItems.items;
          isLoading = false;
        });
      }
    }
  }

  void _toggleEditMode() {
    setState(() {
      isEditMode = !isEditMode;
      if (isEditMode) {
        _wiggleController.repeat(reverse: true);
      } else {
        _wiggleController.stop();
        _wiggleController.value = 0;
        _saveLayout();
      }
    });
  }

  Future<void> _saveLayout() async {
    try {
      await GridLayoutService.saveLayout(items);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Layout opgeslagen!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      AppLogger.debug('[GRID] Error saving: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fout bij opslaan: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _resetLayout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cream,
        title: const Text(
          'Layout resetten?',
          style: TextStyle(color: darkMocha, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Wil je de standaard layout herstellen?',
          style: TextStyle(color: darkMocha),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuleren'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: mochaBrown),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await GridLayoutService.resetLayout();
        await _loadLayout();
        setState(() => isEditMode = false);
        _wiggleController.stop();
        _wiggleController.value = 0;
      } catch (e) {
        AppLogger.debug('[GRID] Error resetting: $e');
      }
    }
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) {
        newIndex -= 1;
      }
      final item = items.removeAt(oldIndex);
      items.insert(newIndex, item);

      // Update positions
      for (int i = 0; i < items.length; i++) {
        items[i] = items[i].copyWith(position: i);
      }
    });
  }

  void _navigateToRoute(String route) {
    if (!isEditMode) {
      context.go(route);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      backgroundColor: cream,
      appBar: AppBar(
        backgroundColor: mochaBrown,
        foregroundColor: Colors.white,
        title: const Text('FamQuest'),
        elevation: 0,
        actions: [
          if (isEditMode)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _resetLayout,
              tooltip: 'Reset naar standaard',
            ),
          IconButton(
            icon: Icon(isEditMode ? Icons.check : Icons.edit),
            onPressed: _toggleEditMode,
            tooltip: isEditMode ? 'Klaar' : 'Bewerk',
          ),
        ],
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 1.0,
        ),
        itemCount: items.length,
        itemBuilder: (context, index) {
          return _buildGridItem(items[index], index);
        },
      ),
    );
  }

  Widget _buildGridItem(GridItem item, int index) {
    return AnimatedBuilder(
      animation: _wiggleController,
      builder: (context, child) {
        final wiggleAngle = isEditMode
            ? (index % 2 == 0 ? 1 : -1) * _wiggleController.value * 0.05
            : 0.0;

        return Transform.rotate(
          angle: wiggleAngle,
          child: LongPressDraggable<int>(
            data: index,
            feedback: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(16),
              child: _buildGridCard(item, isDragging: true),
            ),
            childWhenDragging: Opacity(
              opacity: 0.3,
              child: _buildGridCard(item),
            ),
            onDragStarted: () {
              if (!isEditMode) {
                _toggleEditMode();
              }
              setState(() => draggingIndex = index);
            },
            onDragEnd: (_) {
              setState(() => draggingIndex = null);
            },
            child: DragTarget<int>(
              onAcceptWithDetails: (details) {
                _onReorder(details.data, index);
              },
              builder: (context, candidateData, rejectedData) {
                return GestureDetector(
                  onTap: () => _navigateToRoute(item.route),
                  onLongPress: () {
                    if (!isEditMode) {
                      _toggleEditMode();
                    }
                  },
                  child: _buildGridCard(item),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildGridCard(GridItem item, {bool isDragging = false}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isEditMode ? mochaBrown : item.color.withValues(alpha: 0.3),
          width: isEditMode ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: item.color.withValues(alpha: 0.2),
            blurRadius: isDragging ? 12 : 4,
            offset: Offset(0, isDragging ? 6 : 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: item.color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              item.icon,
              size: 32,
              color: item.color,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              item.label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: darkMocha,
              ),
            ),
          ),
          if (isEditMode) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: lightMocha.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                item.category,
                style: const TextStyle(
                  fontSize: 9,
                  color: mochaBrown,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
