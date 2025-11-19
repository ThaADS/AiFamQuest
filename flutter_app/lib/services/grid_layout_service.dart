import '../core/supabase.dart';
import '../models/grid_item.dart';
import '../core/app_logger.dart';

/// Service for managing user's custom grid layout
/// Stores and retrieves grid item positions from Supabase
class GridLayoutService {
  /// Load user's custom grid layout from database
  static Future<List<GridItem>> loadLayout() async {
    try {
      final user = currentUser;
      if (user == null) {
        return DefaultGridItems.items;
      }

      final userData = await supabase
          .from('users')
          .select('grid_layout')
          .eq('id', user.id)
          .single();

      final gridLayout = userData['grid_layout'] as List<dynamic>?;

      if (gridLayout == null || gridLayout.isEmpty) {
        return DefaultGridItems.items;
      }

      // Convert stored layout to GridItems
      final storedItems = gridLayout
          .map((json) => GridItem.fromJson(json as Map<String, dynamic>))
          .toList();

      // Merge with defaults (in case new features were added)
      final defaultItems = DefaultGridItems.items;
      final result = <GridItem>[];

      // Add all stored items
      result.addAll(storedItems);

      // Add any new default items that aren't in stored layout
      for (final defaultItem in defaultItems) {
        if (!result.any((item) => item.id == defaultItem.id)) {
          result.add(defaultItem.copyWith(
            position: result.length, // Add at the end
          ));
        }
      }

      // Sort by position
      result.sort((a, b) => a.position.compareTo(b.position));

      return result;
    } catch (e) {
      AppLogger.debug('[GRID] Error loading layout: $e');
      return DefaultGridItems.items;
    }
  }

  /// Save user's custom grid layout to database
  static Future<void> saveLayout(List<GridItem> items) async {
    try {
      final user = currentUser;
      if (user == null) return;

      final gridLayout = items.map((item) => item.toJson()).toList();

      await supabase.from('users').update({
        'grid_layout': gridLayout,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', user.id);

      AppLogger.debug('[GRID] Layout saved successfully');
    } catch (e) {
      AppLogger.debug('[GRID] Error saving layout: $e');
      throw Exception('Failed to save grid layout: $e');
    }
  }

  /// Reset to default grid layout
  static Future<void> resetLayout() async {
    try {
      final user = currentUser;
      if (user == null) return;

      await supabase.from('users').update({
        'grid_layout': null,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', user.id);

      AppLogger.debug('[GRID] Layout reset to default');
    } catch (e) {
      AppLogger.debug('[GRID] Error resetting layout: $e');
      throw Exception('Failed to reset grid layout: $e');
    }
  }
}
