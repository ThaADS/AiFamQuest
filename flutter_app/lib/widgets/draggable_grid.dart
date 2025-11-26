import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/grid_item.dart';
import '../services/grid_layout_service.dart';
import '../core/app_logger.dart';

/// Draggable grid widget with iPhone-style interaction
/// - Tap to navigate
/// - Grouped by Category
class DraggableGrid extends StatefulWidget {
  const DraggableGrid({super.key});

  @override
  State<DraggableGrid> createState() => _DraggableGridState();
}

class _DraggableGridState extends State<DraggableGrid> {
  List<GridItem> items = [];
  bool isLoading = true;

  static const mochaBrown = Color(0xFF6B4423);
  static const lightMocha = Color(0xFFB08968);
  static const cream = Color(0xFFF5EBE0);
  static const darkMocha = Color(0xFF3D2817);

  @override
  void initState() {
    super.initState();
    _loadLayout();
  }

  Future<void> _loadLayout() async {
    setState(() => isLoading = true);
    try {
      // Always load default items for now to ensure categories are correct
      // In future, we can merge with saved positions if needed
      final loadedItems = DefaultGridItems.items; 
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

  void _navigateToRoute(String route) {
    context.push(route); // Changed from context.go to context.push for Back button
  }

  Map<String, List<GridItem>> get _groupedItems {
    final grouped = <String, List<GridItem>>{};
    for (var item in items) {
      if (!grouped.containsKey(item.category)) {
        grouped[item.category] = [];
      }
      grouped[item.category]!.add(item);
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final grouped = _groupedItems;
    final categories = grouped.keys.toList();

    return Scaffold(
      backgroundColor: cream,
      appBar: AppBar(
        backgroundColor: mochaBrown,
        foregroundColor: Colors.white,
        title: const Text('AiFamQuest'),
        elevation: 0,
      ),
      body: CustomScrollView(
        padding: EdgeInsets.fromLTRB(
            16, 16, 16, 16 + MediaQuery.of(context).padding.bottom),
        slivers: [
          for (var category in categories) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12, top: 8),
                child: Text(
                  category,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: darkMocha,
                  ),
                ),
              ),
            ),
            SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 1.0,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final item = grouped[category]![index];
                  return _buildGridItem(item);
                },
                childCount: grouped[category]!.length,
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
          // Add extra padding at bottom for safety
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }

  Widget _buildGridItem(GridItem item) {
    return GestureDetector(
      onTap: () => _navigateToRoute(item.route),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: item.color.withValues(alpha: 0.3),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: item.color.withValues(alpha: 0.2),
              blurRadius: 4,
              offset: const Offset(0, 2),
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
          ],
        ),
      ),
    );
  }
}
