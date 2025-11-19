/// Task Provider with Real-time Subscriptions
///
/// Manages task state with:
/// - Real-time updates from Supabase
/// - Offline-first architecture with Hive
/// - Optimistic UI updates
/// - Conflict resolution

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/local_storage.dart';
import '../services/realtime_service.dart';
import '../services/sync_queue.dart';
import '../api/client.dart';
import 'package:uuid/uuid.dart';
import '../core/app_logger.dart';

/// Task status
enum TaskStatus {
  open,
  pendingApproval,
  done,
}

/// Task model
class Task {
  final String id;
  final String familyId;
  final String title;
  final String? description;
  final String category;
  final String? frequency;
  final String? rrule;
  final DateTime? due;
  final List<String> assignees;
  final bool claimable;
  final String? claimedBy;
  final DateTime? claimExpiry;
  final int points;
  final bool photoRequired;
  final bool parentApproval;
  final TaskStatus status;
  final List<String> proofPhotos;
  final String priority;
  final int estimatedMinutes;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int version;
  final bool isDirty;

  Task({
    required this.id,
    required this.familyId,
    required this.title,
    this.description,
    this.category = 'other',
    this.frequency,
    this.rrule,
    this.due,
    this.assignees = const [],
    this.claimable = false,
    this.claimedBy,
    this.claimExpiry,
    this.points = 10,
    this.photoRequired = false,
    this.parentApproval = false,
    this.status = TaskStatus.open,
    this.proofPhotos = const [],
    this.priority = 'medium',
    this.estimatedMinutes = 0,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.version = 1,
    this.isDirty = false,
  });

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['id'] as String,
      familyId: json['familyId'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      category: json['category'] as String? ?? 'other',
      frequency: json['frequency'] as String?,
      rrule: json['rrule'] as String?,
      due: json['due'] != null ? DateTime.parse(json['due'] as String) : null,
      assignees: (json['assignees'] as List?)?.cast<String>() ?? [],
      claimable: json['claimable'] as bool? ?? false,
      claimedBy: json['claimedBy'] as String?,
      claimExpiry: json['claimExpiry'] != null
          ? DateTime.parse(json['claimExpiry'] as String)
          : null,
      points: json['points'] as int? ?? 10,
      photoRequired: json['photoRequired'] as bool? ?? false,
      parentApproval: json['parentApproval'] as bool? ?? false,
      status: _parseStatus(json['status'] as String? ?? 'open'),
      proofPhotos: (json['proofPhotos'] as List?)?.cast<String>() ?? [],
      priority: json['priority'] as String? ?? 'medium',
      estimatedMinutes: json['estimatedMinutes'] as int? ?? 0,
      createdBy: json['createdBy'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      version: json['version'] as int? ?? 1,
      isDirty: json['isDirty'] as bool? ?? false,
    );
  }

  static TaskStatus _parseStatus(String status) {
    switch (status) {
      case 'pendingApproval':
        return TaskStatus.pendingApproval;
      case 'done':
        return TaskStatus.done;
      default:
        return TaskStatus.open;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'familyId': familyId,
      'title': title,
      'description': description,
      'category': category,
      'frequency': frequency,
      'rrule': rrule,
      'due': due?.toIso8601String(),
      'assignees': assignees,
      'claimable': claimable,
      'claimedBy': claimedBy,
      'claimExpiry': claimExpiry?.toIso8601String(),
      'points': points,
      'photoRequired': photoRequired,
      'parentApproval': parentApproval,
      'status': status.name,
      'proofPhotos': proofPhotos,
      'priority': priority,
      'estimatedMinutes': estimatedMinutes,
      'createdBy': createdBy,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'version': version,
      'isDirty': isDirty,
    };
  }

  Task copyWith({
    String? title,
    String? description,
    String? category,
    DateTime? due,
    List<String>? assignees,
    TaskStatus? status,
    List<String>? proofPhotos,
    bool incrementVersion = true,
  }) {
    return Task(
      id: id,
      familyId: familyId,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      frequency: frequency,
      rrule: rrule,
      due: due ?? this.due,
      assignees: assignees ?? this.assignees,
      claimable: claimable,
      claimedBy: claimedBy,
      claimExpiry: claimExpiry,
      points: points,
      photoRequired: photoRequired,
      parentApproval: parentApproval,
      status: status ?? this.status,
      proofPhotos: proofPhotos ?? this.proofPhotos,
      priority: priority,
      estimatedMinutes: estimatedMinutes,
      createdBy: createdBy,
      createdAt: createdAt,
      updatedAt: DateTime.now().toUtc(),
      version: incrementVersion ? version + 1 : version,
      isDirty: true,
    );
  }
}

/// Task state
class TaskState {
  final List<Task> tasks;
  final bool isLoading;
  final String? error;
  final bool isRealtimeConnected;

  TaskState({
    this.tasks = const [],
    this.isLoading = false,
    this.error,
    this.isRealtimeConnected = false,
  });

  TaskState copyWith({
    List<Task>? tasks,
    bool? isLoading,
    String? error,
    bool? isRealtimeConnected,
  }) {
    return TaskState(
      tasks: tasks ?? this.tasks,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      isRealtimeConnected: isRealtimeConnected ?? this.isRealtimeConnected,
    );
  }
}

/// Task provider with real-time updates
class TaskNotifier extends StateNotifier<TaskState> {
  final FamQuestStorage _localStorage;
  // ignore: unused_field
  final ApiClient _apiClient;
  final SyncQueue _syncQueue;
  final SupabaseRealtimeService _realtimeService;

  StreamSubscription? _taskUpdateSubscription;
  StreamSubscription? _connectionStateSubscription;

  TaskNotifier({
    required FamQuestStorage localStorage,
    required ApiClient apiClient,
    required SyncQueue syncQueue,
    required SupabaseRealtimeService realtimeService,
  })  : _localStorage = localStorage,
        _apiClient = apiClient,
        _syncQueue = syncQueue,
        _realtimeService = realtimeService,
        super(TaskState());

  /// Initialize with real-time subscriptions
  Future<void> initialize(String familyId, String userId) async {
    // Listen to real-time task updates
    _taskUpdateSubscription = _realtimeService.taskUpdateStream.listen(
      (update) => _handleRealtimeUpdate(update),
    );

    // Listen to connection state changes
    _connectionStateSubscription = _realtimeService.connectionStateStream.listen(
      (state) {
        this.state = this.state.copyWith(
          isRealtimeConnected: state == RealtimeConnectionState.connected,
        );
      },
    );

    // Load initial data
    await fetchTasks();
  }

  /// Handle real-time updates
  void _handleRealtimeUpdate(Map<String, dynamic> update) {
    final type = update['type'] as String;
    final data = update['data'] as Map<String, dynamic>;

    switch (type) {
      case 'insert':
        _handleTaskInsert(data);
        break;
      case 'update':
        _handleTaskUpdate(data);
        break;
      case 'delete':
        _handleTaskDelete(data);
        break;
    }
  }

  /// Handle task insert from real-time
  void _handleTaskInsert(Map<String, dynamic> data) {
    try {
      final task = Task.fromJson(data);

      // Check if task already exists (avoid duplicates)
      if (state.tasks.any((t) => t.id == task.id)) {
        return;
      }

      // Add to state
      state = state.copyWith(
        tasks: [...state.tasks, task],
      );
    } catch (e) {
      AppLogger.debug('[TaskProvider] Insert error: $e');
    }
  }

  /// Handle task update from real-time
  void _handleTaskUpdate(Map<String, dynamic> data) {
    try {
      final updatedTask = Task.fromJson(data);

      // Update in state
      final updatedTasks = state.tasks.map((task) {
        return task.id == updatedTask.id ? updatedTask : task;
      }).toList();

      state = state.copyWith(tasks: updatedTasks);
    } catch (e) {
      AppLogger.debug('[TaskProvider] Update error: $e');
    }
  }

  /// Handle task delete from real-time
  void _handleTaskDelete(Map<String, dynamic> data) {
    try {
      final taskId = data['id'] as String;

      // Remove from state
      final updatedTasks = state.tasks.where((task) => task.id != taskId).toList();

      state = state.copyWith(tasks: updatedTasks);
    } catch (e) {
      AppLogger.debug('[TaskProvider] Delete error: $e');
    }
  }

  /// Fetch tasks from local storage
  Future<void> fetchTasks() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      // Load from local storage (offline-first)
      final localTasks = await _localStorage.query(
        'tasks',
        where: (task) => task['status'] != 'deleted',
      );

      final tasks = localTasks.map((t) => Task.fromJson(t)).toList();
      state = state.copyWith(tasks: tasks, isLoading: false);

      // Trigger background sync
      _syncQueue.scheduleSyncIfNeeded();
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load tasks: $e',
      );
    }
  }

  /// Create new task (optimistic UI)
  Future<Task> createTask(Task task) async {
    try {
      // Generate ID if not present
      final newTask = Task(
        id: task.id.isEmpty ? const Uuid().v4() : task.id,
        familyId: task.familyId,
        title: task.title,
        description: task.description,
        category: task.category,
        frequency: task.frequency,
        rrule: task.rrule,
        due: task.due,
        assignees: task.assignees,
        claimable: task.claimable,
        points: task.points,
        photoRequired: task.photoRequired,
        parentApproval: task.parentApproval,
        priority: task.priority,
        estimatedMinutes: task.estimatedMinutes,
        createdBy: task.createdBy,
        createdAt: DateTime.now().toUtc(),
        updatedAt: DateTime.now().toUtc(),
        version: 1,
        isDirty: true,
      );

      // Save to local storage immediately
      await _localStorage.put('tasks', newTask.id, newTask.toJson());

      // Queue for sync
      await _syncQueue.enqueue(SyncOperation(
        entityType: 'task',
        operation: 'create',
        entityId: newTask.id,
        data: newTask.toJson(),
      ));

      // Update state
      state = state.copyWith(
        tasks: [...state.tasks, newTask],
      );

      // Trigger background sync
      _syncQueue.scheduleSyncIfNeeded();

      return newTask;
    } catch (e) {
      state = state.copyWith(error: 'Failed to create task: $e');
      rethrow;
    }
  }

  /// Update task (optimistic UI)
  Future<void> updateTask(String id, Task updatedTask) async {
    try {
      // Update local storage
      await _localStorage.put('tasks', id, updatedTask.toJson());

      // Queue for sync
      await _syncQueue.enqueue(SyncOperation(
        entityType: 'task',
        operation: 'update',
        entityId: id,
        data: updatedTask.toJson(),
      ));

      // Update state
      final updatedTasks = state.tasks.map((t) {
        return t.id == id ? updatedTask : t;
      }).toList();

      state = state.copyWith(tasks: updatedTasks);

      // Trigger background sync
      _syncQueue.scheduleSyncIfNeeded();
    } catch (e) {
      state = state.copyWith(error: 'Failed to update task: $e');
      rethrow;
    }
  }

  /// Complete task
  Future<void> completeTask(String id, List<String>? proofPhotos) async {
    try {
      final task = state.tasks.firstWhere((t) => t.id == id);

      final updatedTask = task.copyWith(
        status: task.parentApproval
            ? TaskStatus.pendingApproval
            : TaskStatus.done,
        proofPhotos: proofPhotos ?? task.proofPhotos,
      );

      await updateTask(id, updatedTask);
    } catch (e) {
      state = state.copyWith(error: 'Failed to complete task: $e');
      rethrow;
    }
  }

  /// Delete task (optimistic UI)
  Future<void> deleteTask(String id) async {
    try {
      // Soft delete in local storage
      await _localStorage.delete('tasks', id);

      // Queue for sync
      await _syncQueue.enqueue(SyncOperation(
        entityType: 'task',
        operation: 'delete',
        entityId: id,
        data: {'id': id, 'isDeleted': true},
      ));

      // Update state
      final updatedTasks = state.tasks.where((t) => t.id != id).toList();
      state = state.copyWith(tasks: updatedTasks);

      // Trigger background sync
      _syncQueue.scheduleSyncIfNeeded();
    } catch (e) {
      state = state.copyWith(error: 'Failed to delete task: $e');
      rethrow;
    }
  }

  /// Get tasks for user
  List<Task> getTasksForUser(String userId) {
    return state.tasks.where((task) {
      return task.assignees.contains(userId) ||
          task.claimable ||
          task.createdBy == userId;
    }).toList();
  }

  /// Get tasks by status
  List<Task> getTasksByStatus(TaskStatus status) {
    return state.tasks.where((task) => task.status == status).toList();
  }

  /// Claim a task from the pool
  Future<void> claimTask(String taskId, String userId) async {
    try {
      final task = state.tasks.firstWhere((t) => t.id == taskId);

      // Check if already claimed
      if (task.claimedBy != null && task.claimedBy != userId) {
        throw Exception('Task already claimed by another user');
      }

      final updatedTask = Task(
        id: task.id,
        familyId: task.familyId,
        title: task.title,
        description: task.description,
        category: task.category,
        frequency: task.frequency,
        rrule: task.rrule,
        due: task.due,
        assignees: task.assignees,
        claimable: task.claimable,
        claimedBy: userId,
        claimExpiry: DateTime.now().add(const Duration(minutes: 30)),
        points: task.points,
        photoRequired: task.photoRequired,
        parentApproval: task.parentApproval,
        status: task.status,
        proofPhotos: task.proofPhotos,
        priority: task.priority,
        estimatedMinutes: task.estimatedMinutes,
        createdBy: task.createdBy,
        createdAt: task.createdAt,
        updatedAt: DateTime.now().toUtc(),
        version: task.version + 1,
        isDirty: true,
      );

      await updateTask(taskId, updatedTask);
    } catch (e) {
      state = state.copyWith(error: 'Failed to claim task: $e');
      rethrow;
    }
  }

  /// Release a claimed task back to the pool
  Future<void> releaseTask(String taskId) async {
    try {
      final task = state.tasks.firstWhere((t) => t.id == taskId);

      final updatedTask = Task(
        id: task.id,
        familyId: task.familyId,
        title: task.title,
        description: task.description,
        category: task.category,
        frequency: task.frequency,
        rrule: task.rrule,
        due: task.due,
        assignees: task.assignees,
        claimable: task.claimable,
        claimedBy: null,
        claimExpiry: null,
        points: task.points,
        photoRequired: task.photoRequired,
        parentApproval: task.parentApproval,
        status: task.status,
        proofPhotos: task.proofPhotos,
        priority: task.priority,
        estimatedMinutes: task.estimatedMinutes,
        createdBy: task.createdBy,
        createdAt: task.createdAt,
        updatedAt: DateTime.now().toUtc(),
        version: task.version + 1,
        isDirty: true,
      );

      await updateTask(taskId, updatedTask);
    } catch (e) {
      state = state.copyWith(error: 'Failed to release task: $e');
      rethrow;
    }
  }

  @override
  void dispose() {
    _taskUpdateSubscription?.cancel();
    _connectionStateSubscription?.cancel();
    super.dispose();
  }
}

/// Provider instances
final taskProvider = StateNotifierProvider<TaskNotifier, TaskState>((ref) {
  return TaskNotifier(
    localStorage: FamQuestStorage.instance,
    apiClient: ApiClient.instance,
    syncQueue: SyncQueue.instance,
    realtimeService: SupabaseRealtimeService.instance,
  );
});
