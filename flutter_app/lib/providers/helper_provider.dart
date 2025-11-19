import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/client.dart';
import '../models/helper_models.dart';

/// Helper Provider - State management for helper system
///
/// Manages:
/// - Helper invites (create, list, revoke)
/// - Active helpers (list, update permissions, remove)
/// - Helper tasks (filtered by helper ID)

/// Provider for helper invites list
final helperInvitesProvider =
    StateNotifierProvider<HelperInvitesNotifier, AsyncValue<List<HelperInvite>>>(
  (ref) => HelperInvitesNotifier(),
);

/// Provider for active helpers list
final activeHelpersProvider =
    StateNotifierProvider<ActiveHelpersNotifier, AsyncValue<List<HelperUser>>>(
  (ref) => ActiveHelpersNotifier(),
);

/// Provider for helper tasks (filtered for helper role)
final helperTasksProvider =
    StateNotifierProvider<HelperTasksNotifier, AsyncValue<List<Map<String, dynamic>>>>(
  (ref) => HelperTasksNotifier(),
);

/// Helper Invites Notifier
class HelperInvitesNotifier
    extends StateNotifier<AsyncValue<List<HelperInvite>>> {
  HelperInvitesNotifier() : super(const AsyncValue.loading()) {
    loadInvites();
  }

  /// Load all helper invites
  Future<void> loadInvites() async {
    state = const AsyncValue.loading();
    try {
      final response = await ApiClient.instance.listHelpers();
      final invites = response
          .where((h) => h['isActive'] == true && h['acceptedAt'] == null)
          .map((json) => HelperInvite.fromJson(json))
          .toList();
      state = AsyncValue.data(invites);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  /// Create new helper invite
  Future<HelperInvite> createInvite(CreateHelperInviteRequest request) async {
    try {
      final response = await ApiClient.instance.createHelperInvite(request.toJson());
      final invite = HelperInvite.fromJson(response);

      // Refresh list
      await loadInvites();

      return invite;
    } catch (e) {
      rethrow;
    }
  }

  /// Revoke helper invite
  Future<void> revokeInvite(String inviteId) async {
    try {
      await ApiClient.instance.deactivateHelper(inviteId);

      // Refresh list
      await loadInvites();
    } catch (e) {
      rethrow;
    }
  }

  /// Refresh invites
  Future<void> refresh() async {
    await loadInvites();
  }
}

/// Active Helpers Notifier
class ActiveHelpersNotifier
    extends StateNotifier<AsyncValue<List<HelperUser>>> {
  ActiveHelpersNotifier() : super(const AsyncValue.loading()) {
    loadHelpers();
  }

  /// Load all active helpers
  Future<void> loadHelpers() async {
    state = const AsyncValue.loading();
    try {
      final response = await ApiClient.instance.listHelpers();
      final helpers = response
          .where((h) => h['isActive'] == true && h['acceptedAt'] != null)
          .map((json) => HelperUser.fromJson(json))
          .toList();
      state = AsyncValue.data(helpers);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  /// Update helper permissions
  Future<void> updatePermissions(
    String helperId,
    HelperPermissions permissions,
  ) async {
    try {
      // Backend endpoint would be: PATCH /helpers/:id/permissions
      // For now, we'll use the task update endpoint as a workaround
      await ApiClient.instance.updateTask(
        helperId,
        {'permissions': permissions.toJson()},
      );

      // Refresh list
      await loadHelpers();
    } catch (e) {
      rethrow;
    }
  }

  /// Remove helper
  Future<void> removeHelper(String helperId) async {
    try {
      await ApiClient.instance.deactivateHelper(helperId);

      // Refresh list
      await loadHelpers();
    } catch (e) {
      rethrow;
    }
  }

  /// Refresh helpers
  Future<void> refresh() async {
    await loadHelpers();
  }
}

/// Helper Tasks Notifier
class HelperTasksNotifier
    extends StateNotifier<AsyncValue<List<Map<String, dynamic>>>> {
  HelperTasksNotifier() : super(const AsyncValue.loading()) {
    loadTasks();
  }

  /// Load tasks assigned to helper
  Future<void> loadTasks() async {
    state = const AsyncValue.loading();
    try {
      final tasks = await ApiClient.instance.getHelperTasks();
      final typedTasks = tasks.map((task) => Map<String, dynamic>.from(task)).toList();
      state = AsyncValue.data(typedTasks);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  /// Complete task
  Future<void> completeTask(
    String taskId, {
    List<String>? photoUrls,
    String? note,
  }) async {
    try {
      await ApiClient.instance.completeTask(
        taskId,
        photoUrls: photoUrls,
        note: note,
      );

      // Refresh list
      await loadTasks();
    } catch (e) {
      rethrow;
    }
  }

  /// Refresh tasks
  Future<void> refresh() async {
    await loadTasks();
  }
}

/// Provider for helper permissions editing
final editingHelperPermissionsProvider =
    StateProvider.family<HelperPermissions?, String>((ref, helperId) => null);
