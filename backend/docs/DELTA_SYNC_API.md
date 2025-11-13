# Delta Sync API Documentation

## Overview

The Delta Sync API enables bidirectional offline-first synchronization between client and server. It implements optimistic locking, conflict resolution strategies, and batch transaction support.

## Key Features

- Bidirectional sync (client → server, server → client)
- Optimistic locking with version field
- Intelligent conflict resolution strategies
- Batch transaction support with rollback
- Comprehensive error handling
- Support for multiple entity types

## API Endpoint

**POST** `/sync/delta`

### Request

```json
{
  "last_sync_at": "2025-11-10T12:00:00Z",
  "changes": [
    {
      "entity_type": "task",
      "entity_id": "uuid-123",
      "action": "update",
      "data": {
        "title": "Updated Task",
        "status": "done"
      },
      "version": 2,
      "client_timestamp": "2025-11-11T14:30:00Z"
    }
  ],
  "device_id": "device-uuid"
}
```

**Fields:**
- `last_sync_at`: Timestamp of last successful sync
- `changes`: Array of entity changes since last sync
- `device_id`: Unique device identifier for tracking

### Response

```json
{
  "server_changes": [
    {
      "entity_type": "task",
      "entity_id": "uuid-456",
      "action": "create",
      "data": { ... },
      "version": 1,
      "client_timestamp": "2025-11-11T14:00:00Z"
    }
  ],
  "conflicts": [
    {
      "entity_type": "task",
      "entity_id": "uuid-789",
      "conflict_reason": "Version mismatch",
      "resolution": "server_wins",
      "client_version": 2,
      "server_version": 4,
      "server_data": { ... }
    }
  ],
  "last_sync_at": "2025-11-11T15:00:00Z",
  "success": true,
  "applied_count": 15,
  "error_count": 2
}
```

**Fields:**
- `server_changes`: All server changes since last_sync_at
- `conflicts`: List of conflicts requiring attention
- `last_sync_at`: New timestamp for next sync
- `success`: true if no conflicts
- `applied_count`: Number of client changes applied
- `error_count`: Number of errors encountered

## Conflict Resolution Strategies

### 1. Task Status: "Done Wins"

**Rule:** If one side marks a task as done, that takes precedence.

**Example:**
- Client: Task status → "done"
- Server: Task title updated
- **Resolution:** Apply done status + keep server title

**Rationale:** Task completion is more important than other updates.

### 2. Delete Always Wins

**Rule:** If server deleted entity, ignore client updates.

**Example:**
- Client: Updates deleted task
- Server: Task already deleted
- **Resolution:** Conflict reported, task remains deleted

**Rationale:** Deletion represents intentional removal decision.

### 3. Last-Writer-Wins (LWW)

**Rule:** Compare timestamps, newer change wins.

**Example:**
- Client timestamp: 14:30:00 (newer)
- Server timestamp: 14:25:00
- **Resolution:** Apply client change

**Rationale:** Most recent change reflects latest intent.

### 4. Optimistic Locking

**Rule:** Version field must match for updates.

**Example:**
- Client version: 2
- Server version: 4 (mismatch!)
- **Resolution:** Check timestamp for LWW or report conflict

**Rationale:** Detect concurrent modifications.

## Entity Types Supported

### Tasks
- **Fields:** title, desc, status, assignees, due, points, etc.
- **Version field:** Yes
- **Special rules:** Done wins

### Events
- **Fields:** title, description, start, end, attendees
- **Version field:** No (planned for Phase 2)
- **Special rules:** LWW based on updatedAt

### PointsLedger
- **Fields:** userId, delta, reason, taskId
- **Version field:** No
- **Special rules:** Immutable (server always wins)

### UserStreak
- **Fields:** currentStreak, longestStreak
- **Version field:** No
- **Special rules:** Server always wins (calculated)

### Badge
- **Fields:** code, awardedAt
- **Version field:** No
- **Special rules:** Immutable (server only)

## Usage Examples

### Example 1: Simple Sync (No Conflicts)

```python
# Client sends 3 new tasks
response = requests.post("/sync/delta", json={
    "last_sync_at": "2025-11-10T00:00:00Z",
    "changes": [
        {
            "entity_type": "task",
            "entity_id": "task-1",
            "action": "create",
            "data": {"title": "Task 1", "status": "open"},
            "version": 1,
            "client_timestamp": "2025-11-11T12:00:00Z"
        },
        # ... 2 more tasks
    ],
    "device_id": "phone-123"
})

# Response: success=True, applied_count=3, server_changes=[...]
```

### Example 2: Conflict - Version Mismatch

```python
# Client tries to update task with old version
response = requests.post("/sync/delta", json={
    "last_sync_at": "2025-11-10T00:00:00Z",
    "changes": [
        {
            "entity_type": "task",
            "entity_id": "task-1",
            "action": "update",
            "data": {"title": "New Title"},
            "version": 2,  # Server is at version 4!
            "client_timestamp": "2025-11-11T12:00:00Z"
        }
    ],
    "device_id": "phone-123"
})

# Response: conflict reported with server_wins resolution
```

### Example 3: "Done Wins" Strategy

```python
# Client completed task, server updated title
response = requests.post("/sync/delta", json={
    "last_sync_at": "2025-11-10T00:00:00Z",
    "changes": [
        {
            "entity_type": "task",
            "entity_id": "task-1",
            "action": "update",
            "data": {
                "status": "done",
                "completedAt": "2025-11-11T14:30:00Z"
            },
            "version": 2,  # Server at version 3
            "client_timestamp": "2025-11-11T14:30:00Z"
        }
    ],
    "device_id": "phone-123"
})

# Response: success=True (done wins strategy applied)
```

## Error Handling

### Client Errors (4xx)

- **400 Bad Request**: Invalid payload, missing required fields
- **401 Unauthorized**: Invalid or missing JWT token
- **403 Forbidden**: User not authorized for this family

### Server Errors (5xx)

- **500 Internal Server Error**: Database error, sync failure

### Conflict Handling

Conflicts do not cause HTTP errors. Instead:
- HTTP 200 OK returned
- `conflicts` array contains details
- Client must handle conflicts (manual resolution or accept server data)

## Performance Considerations

### Batch Size

- Recommended: 100 changes per sync
- Maximum: 500 changes per sync
- Large batches may timeout (30s server timeout)

### Frequency

- Background sync: Every 5 minutes
- On-demand sync: After user actions
- Avoid sync loops (implement exponential backoff)

### Bandwidth

- Average sync: 5-50KB
- Large sync (100 tasks): ~200KB
- Use compression for large payloads

## Testing

Run sync tests:

```bash
cd backend
pytest tests/test_sync.py -v
```

**Test Coverage:**
- ✅ No conflicts sync
- ✅ Task done wins strategy
- ✅ Delete wins strategy
- ✅ Version mismatch handling
- ✅ Last-writer-wins (LWW)
- ✅ Batch transaction rollback
- ✅ Empty changes handling
- ✅ Concurrent user sync

## Security

### Authentication

- All sync requests require valid JWT token
- Token contains userId and familyId
- Server validates family membership

### Authorization

- Users can only sync their family data
- Server filters changes by familyId
- No cross-family data leakage

### Data Validation

- All entity data validated against schema
- SQL injection prevented (parameterized queries)
- File size limits enforced

## Monitoring

### Metrics to Track

- Sync frequency per device
- Average sync duration
- Conflict rate (target: <5%)
- Error rate (target: <1%)
- Batch size distribution

### Logging

All sync operations logged:
- User ID and device ID
- Number of changes processed
- Conflicts detected
- Errors encountered

## Troubleshooting

### Issue: High Conflict Rate

**Symptoms:** >10% of syncs have conflicts

**Solutions:**
- Increase sync frequency
- Implement optimistic UI updates
- Educate users on offline limitations

### Issue: Slow Sync Performance

**Symptoms:** Sync takes >5 seconds

**Solutions:**
- Reduce batch size
- Add database indexes
- Enable query caching
- Use connection pooling

### Issue: Data Loss

**Symptoms:** Client changes not appearing on server

**Solutions:**
- Check JWT token validity
- Verify familyId in token
- Review conflict resolution logs
- Ensure transaction commits

## Future Enhancements

**Phase 2:**
- Event versioning for conflict detection
- Partial entity sync (delta of delta)
- Compressed payloads (gzip)
- Sync priority levels
- Real-time sync via WebSockets

**Phase 3:**
- Multi-device conflict resolution UI
- Sync analytics dashboard
- Automatic conflict resolution ML
- Sync replay for debugging
