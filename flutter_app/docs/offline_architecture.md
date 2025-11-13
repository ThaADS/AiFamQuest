# FamQuest Offline-First Architecture Design

**Version:** 1.0
**Author:** System Architect
**Date:** 2025-11-11
**Status:** Design Document
**Risk ID:** RISK-003 (Offline sync data loss - HIGH priority)

---

## Executive Summary

This document defines the offline-first architecture for FamQuest Flutter app to meet PRD v2.1 requirements. The design ensures zero data loss through optimistic locking, comprehensive conflict resolution, and robust sync protocols.

**Key Goals:**
- 100% offline functionality (create/edit/delete tasks, events, points)
- Delta sync: Only changed entities since last sync
- Conflict resolution: PRD rules (done > pendingApproval > open)
- Performance: <10s sync for 100 queued changes
- Security: AES-256 encrypted storage for sensitive data
- Reliability: 50+ conflict test scenarios before beta

---

## 1. Architecture Overview

### 1.1 Three-Layer Model

```
┌─────────────────────────────────────────────────┐
│           UI Layer (Widgets)                    │
│  - Optimistic updates (immediate feedback)      │
│  - ConflictDialog for manual resolution         │
└─────────────────────────────────────────────────┘
                      ↓
┌─────────────────────────────────────────────────┐
│         Business Logic Layer                    │
│  - LocalStorage (Hive CRUD interface)           │
│  - SyncQueue (pending changes tracking)         │
│  - ConflictResolver (automatic resolution)      │
└─────────────────────────────────────────────────┘
                      ↓
┌─────────────────────────────────────────────────┐
│          Persistence Layer                      │
│  - Hive Encrypted Boxes (local storage)         │
│  - Flutter Secure Storage (encryption keys)     │
│  - API Client (network sync)                    │
└─────────────────────────────────────────────────┘
```

### 1.2 Data Flow

**Write Path (Optimistic UI):**
```
User Action → Update Local Hive → Queue Sync → Update UI → Background Sync → Conflict Check → Resolve
```

**Read Path:**
```
Widget Build → Read Local Hive → Display Data (offline-first)
```

**Sync Path:**
```
Network Up → Fetch Server Delta → Compare Versions → Resolve Conflicts → Apply Changes → Push Queue
```

---

## 2. Hive Storage Design

### 2.1 Box Structure

**Encrypted Boxes (sensitive data):**
- `users` - User profiles with PII
- `auth_tokens` - Access tokens and refresh tokens

**Plain Boxes (performance-critical):**
- `tasks` - Task entities with sync metadata
- `events` - Calendar events
- `points_ledger` - Point transactions
- `badges` - Achievement data
- `sync_queue` - Pending API operations
- `sync_metadata` - Last sync timestamps per entity type

### 2.2 Entity Schema (Task Example)

```dart
@HiveType(typeId: 1)
class TaskEntity extends HiveObject {
  @HiveField(0)
  String id; // UUID v4

  @HiveField(1)
  String familyId;

  @HiveField(2)
  String title;

  @HiveField(3)
  String? description;

  @HiveField(4)
  String status; // "open" | "pendingApproval" | "done"

  @HiveField(5)
  List<String> assignees;

  @HiveField(6)
  DateTime? due;

  @HiveField(7)
  int points;

  @HiveField(8)
  bool photoRequired;

  @HiveField(9)
  bool parentApproval;

  // Sync metadata (critical for conflict resolution)
  @HiveField(10)
  int version; // Optimistic lock version

  @HiveField(11)
  DateTime updatedAt; // UTC timestamp

  @HiveField(12)
  bool isDirty; // Has local changes not synced

  @HiveField(13)
  bool isDeleted; // Soft delete flag

  @HiveField(14)
  String lastModifiedBy; // User ID who made change
}
```

### 2.3 Encryption Key Management

```dart
// Generate key once on first launch
final key = Hive.generateSecureKey();

// Store securely using flutter_secure_storage
final secureStorage = FlutterSecureStorage();
await secureStorage.write(key: 'hive_encryption_key', value: base64Encode(key));

// Retrieve on app startup
final keyString = await secureStorage.read(key: 'hive_encryption_key');
final key = base64Decode(keyString);

// Open encrypted box
final encryptedBox = await Hive.openBox('users',
  encryptionCipher: HiveAesCipher(key));
```

**Key Rotation Strategy (Future Phase 2):**
- Generate new key every 90 days
- Re-encrypt boxes with new key
- Maintain key history for 1 year

---

## 3. Delta Sync Protocol

### 3.1 Sync Metadata

Track last sync timestamp per entity type:

```dart
class SyncMetadata {
  String entityType; // "task", "event", "user"
  DateTime lastSyncAt; // UTC timestamp
  int successfulSyncs; // Counter for metrics
  int failedSyncs; // Counter for retry logic
}
```

### 3.2 Delta Request (Client → Server)

```http
POST /api/sync/delta
Authorization: Bearer {token}
Content-Type: application/json

{
  "lastSyncTimestamps": {
    "tasks": "2025-11-11T10:00:00Z",
    "events": "2025-11-11T09:30:00Z"
  },
  "pendingChanges": [
    {
      "entityType": "task",
      "operation": "update",
      "entityId": "uuid-123",
      "version": 3,
      "data": { /* task fields */ },
      "updatedAt": "2025-11-11T10:15:00Z"
    }
  ]
}
```

### 3.3 Delta Response (Server → Client)

```http
200 OK
Content-Type: application/json

{
  "serverChanges": [
    {
      "entityType": "task",
      "operation": "update",
      "entityId": "uuid-456",
      "version": 5,
      "data": { /* task fields */ },
      "updatedAt": "2025-11-11T10:10:00Z"
    }
  ],
  "conflicts": [
    {
      "entityType": "task",
      "entityId": "uuid-123",
      "clientVersion": 3,
      "serverVersion": 4,
      "clientData": { /* client state */ },
      "serverData": { /* server state */ },
      "conflictType": "concurrent_update"
    }
  ],
  "syncTimestamp": "2025-11-11T10:20:00Z"
}
```

### 3.4 Sync Triggers

Auto-sync activates on:
1. **App Resume** - User returns to app
2. **Network Up** - Connectivity restored (ConnectivityPlus)
3. **Interval** - Every 5 minutes while app active
4. **Pull-to-Refresh** - User swipes down on lists
5. **Manual Button** - Sync Now button in settings

---

## 4. Conflict Resolution Strategy

### 4.1 Conflict Detection

Conflicts occur when:
- **Concurrent Update**: Client and server both modified entity (version mismatch)
- **Delete-Update**: Client deletes, server updates (or vice versa)
- **Offline Create Collision**: Two clients create same entity offline (UUID collision - rare)

### 4.2 Resolution Rules (PRD Priority)

**Rule 1: Task Status Priority (Automatic)**
```
done > pendingApproval > open
```
If client has `done` and server has `open`, keep `done`.

**Rule 2: Last Writer Wins (Automatic)**
```
Compare updatedAt timestamps (UTC):
- If client.updatedAt > server.updatedAt → Keep client
- If server.updatedAt > client.updatedAt → Keep server
- If equal → Keep server (tie-breaker)
```

**Rule 3: Delete Wins (Automatic)**
```
If either side deleted entity, apply delete (isDeleted=true)
```

**Rule 4: Manual Resolution (UI Dialog)**
```
If rules 1-3 don't apply cleanly:
- Show ConflictDialog with both versions
- User chooses: "Keep Local" | "Keep Server" | "Merge"
- Queue failed auto-resolves for manual review
```

### 4.3 Conflict Scenarios (10+ Examples)

| Scenario | Client State | Server State | Resolution | Rule |
|----------|--------------|--------------|------------|------|
| 1. Task complete race | status: done, v3 | status: open, v3 | Keep done | Rule 1 |
| 2. Concurrent title edit | title: "Clean", v3, t1 | title: "Tidy", v3, t2 | Keep t2 if t2>t1 | Rule 2 |
| 3. Delete vs update | isDeleted: true | title: "New", v4 | Apply delete | Rule 3 |
| 4. Points mismatch | points: 20 | points: 15 | Manual dialog | Rule 4 |
| 5. Assignee conflict | assignees: [A] | assignees: [B] | Manual dialog | Rule 4 |
| 6. Offline create same UUID | id: uuid-X, v1 | id: uuid-X, v1 | Regenerate client UUID | Rare edge case |
| 7. Photo added offline | proofPhotos: [url] | proofPhotos: [] | Keep client (newer) | Rule 2 |
| 8. Parent approval race | status: pendingApproval | status: done | Keep done | Rule 1 |
| 9. Due date change | due: Nov 12 | due: Nov 13 | Last writer wins | Rule 2 |
| 10. Soft delete restore | isDeleted: false, v5 | isDeleted: true, v4 | Keep v5 (restore) | Rule 2 |

**Additional Complex Scenarios (40+ for testing):**
- Multiple field conflicts on same entity
- Cascading deletes (task deleted, points ledger updated)
- Recurrence conflicts (RRULE edited offline)
- Family membership changes (user removed while offline)

---

## 5. SyncQueue Implementation

### 5.1 Queue Entry Schema

```dart
class SyncOperation {
  String id; // UUID for queue entry
  String entityType; // "task", "event", etc.
  String operation; // "create", "update", "delete"
  String entityId; // Entity UUID
  Map<String, dynamic> data; // Full entity JSON
  int retryCount; // Exponential backoff tracker
  DateTime queuedAt; // UTC timestamp
  DateTime? lastAttemptAt; // UTC timestamp
  String? errorMessage; // Last error for debugging
}
```

### 5.2 Queue Processing

**Retry Logic (Exponential Backoff):**
```dart
int getBackoffSeconds(int retryCount) {
  // 1s, 2s, 4s, 8s, 16s (max 16s)
  return math.min(math.pow(2, retryCount).toInt(), 16);
}
```

**Failure Handling:**
- After 5 retries (31s total wait): Move to failed queue
- Show persistent notification: "X items need attention"
- User reviews in Settings → Sync Status
- Option: "Retry All" or "Discard"

### 5.3 Queue Persistence

Store queue in Hive box `sync_queue`:
```dart
final queueBox = await Hive.openBox<SyncOperation>('sync_queue');
```

**Queue Monitoring:**
- Track queue size (alert if >100 items)
- Estimate sync time (100 items @ 100ms each = 10s)
- Show progress bar during sync

---

## 6. LocalStorage Service API

### 6.1 Interface Design

```dart
abstract class ILocalStorage {
  // CRUD operations
  Future<T?> get<T>(String id);
  Future<List<T>> getAll<T>();
  Future<void> put<T>(String id, T entity);
  Future<void> delete(String id);

  // Query interface
  Future<List<T>> query<T>({
    List<Filter>? filters,
    List<Sort>? sorts,
    int? limit,
    int? offset,
  });

  // Sync metadata
  Future<void> markDirty(String id);
  Future<void> markClean(String id);
  Future<List<String>> getDirtyIds<T>();

  // Conflict management
  Future<void> storeConflict(ConflictData conflict);
  Future<List<ConflictData>> getPendingConflicts();
}
```

### 6.2 Implementation Example (Tasks)

```dart
class LocalStorage implements ILocalStorage {
  late Box<TaskEntity> _taskBox;

  Future<void> init() async {
    Hive.registerAdapter(TaskEntityAdapter());
    _taskBox = await Hive.openBox<TaskEntity>('tasks');
  }

  @override
  Future<TaskEntity?> get<TaskEntity>(String id) async {
    return _taskBox.get(id);
  }

  @override
  Future<void> put<TaskEntity>(String id, TaskEntity entity) async {
    entity.isDirty = true;
    entity.updatedAt = DateTime.now().toUtc();
    entity.version++; // Increment optimistic lock version
    await _taskBox.put(id, entity);
  }

  @override
  Future<List<TaskEntity>> query<TaskEntity>({
    List<Filter>? filters,
    List<Sort>? sorts,
    int? limit,
  }) async {
    var values = _taskBox.values.toList();

    // Apply filters
    if (filters != null) {
      for (final filter in filters) {
        values = values.where((v) => filter.apply(v)).toList();
      }
    }

    // Apply sorts
    if (sorts != null) {
      // Sorting logic
    }

    // Apply limit
    if (limit != null) {
      values = values.take(limit).toList();
    }

    return values;
  }
}
```

---

## 7. API Client Refactor

### 7.1 Offline-First Wrapper

**Old Pattern (Direct API):**
```dart
// ❌ Fails immediately when offline
final tasks = await apiClient.listTasks();
```

**New Pattern (Offline-First):**
```dart
// ✅ Reads from local Hive first, syncs in background
final tasks = await localStorage.getAll<TaskEntity>();
syncQueue.scheduleSyncIfNeeded(); // Non-blocking background sync
```

### 7.2 Write Operations

```dart
// Create task (optimistic UI)
Future<TaskEntity> createTask(TaskEntity task) async {
  // 1. Write to local Hive immediately
  task.id = Uuid().v4();
  task.version = 1;
  task.isDirty = true;
  task.updatedAt = DateTime.now().toUtc();
  await localStorage.put(task.id, task);

  // 2. Queue for sync
  await syncQueue.enqueue(SyncOperation(
    entityType: 'task',
    operation: 'create',
    entityId: task.id,
    data: task.toJson(),
  ));

  // 3. Trigger background sync (non-blocking)
  syncQueue.scheduleSyncIfNeeded();

  // 4. Return immediately (optimistic)
  return task;
}
```

### 7.3 Sync Coordination

```dart
class ApiClient {
  final LocalStorage _localStorage;
  final SyncQueue _syncQueue;
  final ConflictResolver _conflictResolver;

  Future<SyncResult> performSync() async {
    // 1. Get last sync timestamps
    final lastSyncTimestamps = await _localStorage.getLastSyncTimestamps();

    // 2. Get dirty entities (pending changes)
    final pendingChanges = await _syncQueue.getPendingOperations();

    // 3. Send delta request to server
    final response = await http.post('/api/sync/delta', body: {
      'lastSyncTimestamps': lastSyncTimestamps,
      'pendingChanges': pendingChanges.map((c) => c.toJson()).toList(),
    });

    // 4. Apply server changes
    final serverChanges = response['serverChanges'];
    for (final change in serverChanges) {
      await _localStorage.applyServerChange(change);
    }

    // 5. Resolve conflicts
    final conflicts = response['conflicts'];
    for (final conflict in conflicts) {
      final resolved = await _conflictResolver.resolve(conflict);
      if (resolved.needsManualReview) {
        await _localStorage.storeConflict(conflict);
      } else {
        await _localStorage.applyResolution(resolved);
      }
    }

    // 6. Update sync metadata
    await _localStorage.updateLastSyncTimestamp(response['syncTimestamp']);

    // 7. Clear processed queue items
    await _syncQueue.clearProcessed(pendingChanges);

    return SyncResult(
      synced: pendingChanges.length,
      conflicts: conflicts.length,
      failed: 0,
    );
  }
}
```

---

## 8. ConflictDialog UI

### 8.1 Widget Design

```dart
class ConflictDialog extends StatelessWidget {
  final ConflictData conflict;
  final Function(ConflictResolution) onResolve;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Sync Conflict: ${conflict.entityType}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Your changes and server changes conflict. Choose:'),
          SizedBox(height: 16),

          // Local version
          _ConflictVersionCard(
            title: 'Your Version (Local)',
            data: conflict.clientData,
            timestamp: conflict.clientUpdatedAt,
          ),

          SizedBox(height: 8),

          // Server version
          _ConflictVersionCard(
            title: 'Server Version',
            data: conflict.serverData,
            timestamp: conflict.serverUpdatedAt,
          ),

          SizedBox(height: 16),

          // Diff viewer (show only changed fields)
          _ConflictDiffView(conflict: conflict),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => onResolve(ConflictResolution.keepLocal),
          child: Text('Keep Mine'),
        ),
        TextButton(
          onPressed: () => onResolve(ConflictResolution.keepServer),
          child: Text('Keep Server'),
        ),
        if (conflict.canMerge)
          TextButton(
            onPressed: () => onResolve(ConflictResolution.merge),
            child: Text('Merge Both'),
          ),
      ],
    );
  }
}
```

### 8.2 Merge Strategy (Complex Conflicts)

For fields that can be merged:
- **Lists (assignees)**: Union of both lists
- **Timestamps**: Keep most recent
- **Numeric (points)**: Sum or max (configurable)
- **Text (description)**: Append with separator

---

## 9. Testing Strategy

### 9.1 Unit Tests (50+ Scenarios)

**Conflict Resolution Tests:**
```dart
group('ConflictResolver', () {
  test('Task status: done beats open', () {
    final client = TaskEntity(status: 'done', version: 3);
    final server = TaskEntity(status: 'open', version: 3);
    final resolved = resolver.resolve(client, server);
    expect(resolved.status, 'done');
  });

  test('Last writer wins: newer timestamp', () {
    final client = TaskEntity(title: 'A', updatedAt: t1);
    final server = TaskEntity(title: 'B', updatedAt: t2); // t2 > t1
    final resolved = resolver.resolve(client, server);
    expect(resolved.title, 'B');
  });

  test('Delete wins over update', () {
    final client = TaskEntity(isDeleted: true);
    final server = TaskEntity(isDeleted: false, title: 'New');
    final resolved = resolver.resolve(client, server);
    expect(resolved.isDeleted, true);
  });

  // ... 47 more scenarios
});
```

**SyncQueue Tests:**
```dart
group('SyncQueue', () {
  test('Exponential backoff: 1s, 2s, 4s, 8s', () {
    expect(queue.getBackoffSeconds(0), 1);
    expect(queue.getBackoffSeconds(1), 2);
    expect(queue.getBackoffSeconds(2), 4);
    expect(queue.getBackoffSeconds(3), 8);
  });

  test('Queue persists across app restarts', () async {
    await queue.enqueue(op1);
    await Hive.close(); // Simulate app kill
    await Hive.openBox('sync_queue');
    final loaded = await queue.getPendingOperations();
    expect(loaded.length, 1);
  });
});
```

### 9.2 Integration Tests

```dart
testWidgets('Offline → Online → Sync → No Data Loss', (tester) async {
  // 1. Start offline
  await tester.pumpWidget(MyApp());
  connectivityService.setOffline();

  // 2. Create task offline
  await tester.tap(find.byIcon(Icons.add));
  await tester.enterText(find.byType(TextField), 'Test Task');
  await tester.tap(find.text('Save'));
  await tester.pumpAndSettle();

  // 3. Verify task in local storage
  final tasks = await localStorage.getAll<TaskEntity>();
  expect(tasks.length, 1);
  expect(tasks.first.isDirty, true);

  // 4. Go online
  connectivityService.setOnline();
  await tester.pump(Duration(seconds: 1)); // Wait for sync trigger

  // 5. Verify sync completed
  await tester.pump(Duration(seconds: 2)); // Wait for sync
  final syncedTasks = await localStorage.getAll<TaskEntity>();
  expect(syncedTasks.first.isDirty, false);

  // 6. Verify server received task
  final serverTasks = await apiClient.listTasks();
  expect(serverTasks.length, 1);
});
```

### 9.3 Stress Test

```dart
test('Sync 1000 local changes in <10s', () async {
  // Create 1000 tasks offline
  for (int i = 0; i < 1000; i++) {
    await localStorage.put('task-$i', TaskEntity(title: 'Task $i'));
  }

  // Measure sync time
  final stopwatch = Stopwatch()..start();
  await apiClient.performSync();
  stopwatch.stop();

  expect(stopwatch.elapsedMilliseconds, lessThan(10000)); // <10s

  // Verify all synced
  final remaining = await syncQueue.getPendingOperations();
  expect(remaining.length, 0);
});
```

---

## 10. Performance Optimization

### 10.1 Hive Performance Tips

**Use Lazy Boxes for Large Collections:**
```dart
// ❌ Loads all 1000 tasks into memory
final box = await Hive.openBox<TaskEntity>('tasks');

// ✅ Loads on-demand
final lazyBox = await Hive.openLazyBox<TaskEntity>('tasks');
final task = await lazyBox.get('task-123'); // Only loads this one
```

**Batch Writes:**
```dart
// ❌ 100 separate writes (slow)
for (final task in tasks) {
  await box.put(task.id, task);
}

// ✅ Single batch write (fast)
await box.putAll(Map.fromEntries(
  tasks.map((t) => MapEntry(t.id, t))
));
```

**Indexes for Queries:**
```dart
// Custom index for fast filtering
final tasksByStatus = <String, List<String>>{}; // status -> [taskIds]
```

### 10.2 Network Optimization

**Compress Sync Payload:**
```dart
// Use gzip compression for delta sync
final compressed = gzip.encode(utf8.encode(jsonEncode(payload)));
```

**Batch API Calls:**
```dart
// ❌ 50 separate POST /tasks calls
for (final task in tasks) {
  await http.post('/tasks', body: task.toJson());
}

// ✅ Single POST /tasks/batch call
await http.post('/tasks/batch', body: tasks.map((t) => t.toJson()).toList());
```

---

## 11. Monitoring & Metrics

### 11.1 Sync Metrics

Track in analytics:
- Sync success rate (target: >95%)
- Sync duration (p50, p95, p99)
- Conflict rate (target: <5%)
- Auto-resolve rate (target: >90%)
- Queue size (alert if >100)

### 11.2 Error Logging

```dart
class SyncError {
  String operation; // "create_task", "sync_delta"
  String errorMessage;
  String stackTrace;
  Map<String, dynamic> context; // Entity data
  DateTime occurredAt;
}
```

Send to Sentry with:
- User ID (hashed)
- Device info (OS, app version)
- Network state (WiFi, 4G, offline)
- Queue size at time of error

---

## 12. Beta Testing Plan

### 12.1 Test Cohort

**50 Families, 30 Days:**
- 10 families: Heavy users (5+ members, 20+ tasks/week)
- 20 families: Normal users (3-4 members, 10+ tasks/week)
- 20 families: Light users (2 members, 5+ tasks/week)

### 12.2 Test Scenarios

Instruct beta users to:
1. Create tasks offline (airplane mode)
2. Edit tasks while offline
3. Go online and observe sync
4. Have 2 family members edit same task simultaneously
5. Delete task on one device, edit on another
6. Force kill app during sync
7. Turn off WiFi randomly during usage

### 12.3 Success Criteria

**Zero Data Loss:**
- No reports of missing tasks/events
- All conflicts resolved (manual or auto)
- Sync queue cleared successfully

**Performance:**
- Sync completes in <10s (p95)
- No UI jank during sync
- No app crashes related to sync

**User Satisfaction:**
- NPS ≥ +30 for offline functionality
- <5% report sync confusion
- 0 critical bugs

---

## 13. Rollout Plan

### 13.1 Phased Rollout

**Week 1-2: Internal Alpha (5 families)**
- Core team + friends/family
- Test basic offline CRUD
- Fix critical bugs

**Week 3-6: Beta Testing (50 families)**
- Recruit via parenting blogs
- Monitor sync metrics daily
- Weekly feedback calls

**Week 7-8: Polish & Prep**
- Fix all P0/P1 bugs
- Write user documentation
- Prepare App Store listing

**Week 9: Public Launch**
- Submit to App Store / Play Store
- Launch marketing campaign

### 13.2 Rollback Strategy

If critical bugs found:
1. Disable sync temporarily (local-only mode)
2. Deploy hotfix within 24h
3. Notify users via push notification
4. Offer data export (JSON/CSV)

---

## 14. Future Enhancements (Phase 2)

### 14.1 Advanced Features

**Selective Sync:**
- User chooses which entity types to sync
- Save bandwidth on mobile data

**Compression:**
- Compress Hive boxes (reduce storage by 50%)
- Use MessagePack instead of JSON for sync

**P2P Sync:**
- Family members sync directly (Bluetooth/WiFi Direct)
- No server needed for local network

**Incremental Backup:**
- Daily encrypted backup to cloud (Google Drive / iCloud)
- User can restore from backup

### 14.2 AI-Assisted Conflict Resolution

Use OpenRouter LLM to suggest merge:
```
Prompt: "Client has task title 'Clean room', server has 'Tidy bedroom'.
         Suggest a merged title that combines both intents."
Response: "Tidy and clean bedroom"
```

---

## 15. Conclusion

This offline-first architecture ensures FamQuest works 100% offline while preventing data loss through:

1. **Optimistic locking** (version field)
2. **Comprehensive conflict resolution** (PRD rules + manual review)
3. **Robust sync queue** (exponential backoff, retry logic)
4. **Encrypted storage** (AES-256 for sensitive data)
5. **Extensive testing** (50+ conflict scenarios)

**Risk Mitigation:**
- RISK-003 severity reduced from HIGH to LOW after implementation
- Beta testing validates real-world usage patterns
- Rollback strategy protects against critical bugs

**Next Steps:**
1. Implement LocalStorage service (Week 8)
2. Implement SyncQueue service (Week 9)
3. Implement ConflictResolver (Week 9)
4. Refactor ApiClient (Week 10)
5. Write test suite (Week 10)
6. Beta testing (Week 11-14)

---

**Document Status:** Ready for Implementation Review
**Approval Required:** System Architect, Backend Engineer, Frontend Engineer
**Target Start Date:** Week 8 (Phase 3 timeline)
