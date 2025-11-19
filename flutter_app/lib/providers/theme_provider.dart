import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/app_theme.dart';
import '../core/supabase.dart';
import '../core/app_logger.dart';

/// Theme State Notifier
///
/// Manages theme changes and persists to Supabase users.theme column
class ThemeNotifier extends StateNotifier<AppThemeData> {
  ThemeNotifier() : super(AppThemeData.cartoony) {
    _loadTheme();
  }

  /// Load theme from Supabase user profile
  Future<void> _loadTheme() async {
    try {
      final user = currentUser;
      if (user == null) return;

      final data = await supabase
          .from('users')
          .select('theme')
          .eq('id', user.id)
          .single();

      final themeId = data['theme'] as String? ?? 'cartoony';
      state = AppThemeData.fromString(themeId);

      AppLogger.debug('[THEME] Loaded theme: $themeId');
    } catch (e) {
      AppLogger.debug('[THEME] Error loading theme: $e');
      // Keep default cartoony theme on error
    }
  }

  /// Change theme and persist to database
  Future<void> setTheme(AppThemeData theme) async {
    try {
      final user = currentUser;
      if (user == null) {
        AppLogger.debug('[THEME] No user logged in, cannot save theme');
        return;
      }

      // Update state immediately (optimistic UI)
      state = theme;

      // Persist to database
      await supabase.from('users').update({
        'theme': theme.id,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', user.id);

      AppLogger.debug('[THEME] Theme changed to: ${theme.id}');
    } catch (e) {
      AppLogger.debug('[THEME] Error saving theme: $e');
      // Revert to previous theme on error
      await _loadTheme();
      rethrow;
    }
  }

  /// Reload theme from database (useful after login)
  Future<void> reloadTheme() async {
    await _loadTheme();
  }
}

/// Global theme provider
final themeProvider = StateNotifierProvider<ThemeNotifier, AppThemeData>((ref) {
  return ThemeNotifier();
});
