# Backend Coordination Required for FamQuest Features

**Frontend Implementation**: 100% Complete
**Backend Implementation**: Required for deployment
**Coordination Agent**: python-expert (backend agent)

---

## Overview

The Flutter frontend has been fully implemented with two major features:
1. **Task Recurrence UI** (100% complete)
2. **Photo Upload System** (100% complete)

The backend MUST implement the following endpoints for these features to work:

---

## Priority 1: Photo Upload Endpoints

### 1.1 Media Upload Endpoint

```python
@router.post("/media/upload")
async def upload_media(
    file: UploadFile,
    current_user: User = Depends(get_current_user)
):
    """
    Upload photo to S3 with compression and AV scanning

    Request:
    - Content-Type: multipart/form-data
    - Body: file (image/jpeg, image/png)
    - Max size: 5MB

    Response:
    {
        "url": "https://s3.amazonaws.com/famquest-photos/...",
        "mediaId": "uuid-v4",
        "thumbnailUrl": "https://s3.amazonaws.com/famquest-photos/thumb_...",
        "fileSizeBytes": 1234567,
        "mimeType": "image/jpeg",
        "uploadedAt": "2025-11-11T10:30:00Z"
    }

    Implementation Requirements:
    - Validate file type (JPEG, PNG only)
    - Validate file size (max 5MB)
    - Generate unique filename: {userId}_{timestamp}_{uuid}.jpg
    - Upload to S3 bucket: famquest-task-photos
    - Generate thumbnail (200x200)
    - Run AV scan (async)
    - Store metadata in media table
    - Return presigned URL (expires 24h)
    """
    pass
```

**Database Schema**:
```sql
CREATE TABLE media (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    url TEXT NOT NULL,
    thumbnail_url TEXT,
    file_size_bytes INTEGER,
    mime_type TEXT,
    uploaded_at TIMESTAMP DEFAULT NOW(),
    uploaded_by UUID REFERENCES users(id),
    task_id UUID REFERENCES tasks(id),
    av_scan_status TEXT DEFAULT 'pending' CHECK (av_scan_status IN ('pending', 'clean', 'malware'))
);
```

### 1.2 Enhanced Task Completion Endpoint

```python
@router.post("/tasks/{task_id}/complete")
async def complete_task(
    task_id: str,
    completion: TaskCompletionRequest,
    current_user: User = Depends(get_current_user)
):
    """
    Complete task with optional photo proof

    Request Body:
    {
        "photo_urls": ["https://s3.../photo1.jpg", "https://s3.../photo2.jpg"],
        "note": "Optional completion note"
    }

    Response:
    {
        "status": "done" | "pending_approval",
        "points_earned": 20
    }

    Logic:
    1. Validate task exists and belongs to current user
    2. If task.photo_required == True:
       - Validate len(photo_urls) > 0 (400 error if empty)
    3. Update task:
       - proof_photos = photo_urls
       - completion_note = note
       - completed_at = NOW()
       - completed_by = current_user.id
    4. If task.parent_approval == True:
       - status = 'pending_approval'
       - return immediately (no points yet)
    5. Else:
       - status = 'done'
       - Award points immediately
       - Update user balance
       - Check badge triggers
       - Update streaks
    """
    pass
```

**Database Schema Update**:
```sql
ALTER TABLE tasks ADD COLUMN proof_photos TEXT[];
ALTER TABLE tasks ADD COLUMN completion_note TEXT;
ALTER TABLE tasks ADD COLUMN quality_rating INTEGER CHECK (quality_rating >= 1 AND quality_rating <= 5);
```

### 1.3 Pending Approval Endpoint

```python
@router.get("/tasks/pending-approval")
async def get_pending_approval_tasks(
    current_user: User = Depends(get_current_user)
):
    """
    Get all tasks pending parent approval

    Response:
    [
        {
            "id": "task-uuid",
            "title": "Clean bedroom",
            "assigned_to": "user-uuid",
            "assigned_to_name": "Emma",
            "proof_photos": ["https://s3.../photo.jpg"],
            "completion_note": "All done!",
            "completed_at": "2025-11-11T10:30:00Z",
            "points": 20
        }
    ]

    Logic:
    1. Verify current_user is parent (role check)
    2. Query tasks WHERE:
       - status = 'pending_approval'
       - family_id = current_user.family_id
    3. Join with users table for assigned_to_name
    4. Order by completed_at DESC
    """
    pass
```

### 1.4 Approval Endpoint

```python
@router.post("/tasks/{task_id}/approve")
async def approve_task(
    task_id: str,
    approval: TaskApprovalRequest,
    current_user: User = Depends(get_current_user)
):
    """
    Approve or reject task with quality rating

    Request Body:
    {
        "approved": true,
        "quality_rating": 4,  # 1-5 stars
        "reason": "Great job!" | "Needs improvement"
    }

    Response:
    {
        "points_awarded": 22,  # base 20 * 1.1 (4-star multiplier)
        "streak_bonus": 2
    }

    Logic:
    1. Verify current_user is parent
    2. Validate task exists and is pending_approval
    3. If approved == True:
       - Calculate points with quality multiplier:
         - 5 stars: 1.2x
         - 4 stars: 1.1x
         - 3 stars: 1.0x
         - 2 stars: 0.9x
         - 1 star: 0.8x
       - Award points to user
       - Update task: status='done', quality_rating
       - Check badge triggers
       - Update streaks
       - Send notification to child
    4. Else (rejected):
       - Update task: status='open', clear completed_at
       - Send notification with reason
    """
    pass
```

**Quality Multiplier Table**:
| Stars | Multiplier | Example (20 pts) |
|-------|-----------|------------------|
| 5     | 1.2x      | 24 points        |
| 4     | 1.1x      | 22 points        |
| 3     | 1.0x      | 20 points        |
| 2     | 0.9x      | 18 points        |
| 1     | 0.8x      | 16 points        |

### 1.5 Auto-Approval Cron Job

```python
@cron.scheduled("0 */6 * * *")  # Every 6 hours
async def auto_approve_old_tasks():
    """
    Auto-approve tasks pending approval for >24h

    Logic:
    1. Query tasks WHERE:
       - status = 'pending_approval'
       - completed_at < NOW() - INTERVAL '24 hours'
    2. For each task:
       - Award points (base, no multiplier)
       - Update status = 'done'
       - Send notification: "Auto-approved"
    """
    pass
```

---

## Priority 2: Recurring Tasks Endpoints

**STATUS**: Backend 100% ready (RRULE expansion + rotation strategies)

Verify these endpoints exist and work correctly:

### 2.1 List Recurring Tasks
```
GET /tasks/recurring
Response: [RecurringTask]
```

### 2.2 Create Recurring Task
```
POST /tasks/recurring
Body: {
    title, description, category, rrule,
    rotation_strategy, assignee_ids, points,
    estimated_minutes, photo_required, parent_approval
}
Response: RecurringTask
```

### 2.3 Update Recurring Task
```
PUT /tasks/recurring/{id}
Body: Same as create
Response: RecurringTask
```

### 2.4 Delete Recurring Task
```
DELETE /tasks/recurring/{id}
Response: 204 No Content
```

### 2.5 Pause/Resume
```
POST /tasks/recurring/{id}/pause
POST /tasks/recurring/{id}/resume
Response: 200 OK
```

### 2.6 Get Occurrences
```
GET /tasks/recurring/{id}/occurrences
Response: [Occurrence]
```

### 2.7 Preview Occurrences
```
GET /tasks/recurring/{id}/preview?limit=5
Response: [
    {
        date: "2025-11-13T10:00:00Z",
        assigned_to: "user-uuid",
        assigned_to_name: "Emma"
    }
]
```

---

## Priority 3: Supporting Endpoints

### 3.1 Family Members Endpoint
```python
@router.get("/users/family")
async def get_family_members(
    current_user: User = Depends(get_current_user)
):
    """
    Get all family members for assignee selection

    Response:
    [
        {
            "id": "user-uuid",
            "name": "Emma",
            "avatar": "https://s3.../avatar.jpg",
            "role": "child"
        }
    ]
    """
    pass
```

### 3.2 User Photos Endpoint
```python
@router.get("/users/{user_id}/photos")
async def get_user_photos(
    user_id: str,
    current_user: User = Depends(get_current_user)
):
    """
    Get all completed task photos for a user

    Response:
    [
        {
            "photo_url": "https://s3.../photo.jpg",
            "task_title": "Clean bedroom",
            "completed_at": "2025-11-11T10:30:00Z",
            "points_earned": 20
        }
    ]
    """
    pass
```

---

## S3 Configuration

### Bucket Setup
```yaml
Bucket Name: famquest-task-photos
Region: us-east-1
ACL: Private (presigned URLs only)

Lifecycle Rules:
  - Delete objects older than 90 days
  - Transition to Glacier after 30 days

CORS Configuration:
  - AllowOrigins: ["https://app.famquest.com"]
  - AllowMethods: ["GET", "PUT"]
  - AllowHeaders: ["*"]
  - MaxAge: 3600

Object Naming:
  - Photos: {userId}_{timestamp}_{uuid}.jpg
  - Thumbnails: thumb_{userId}_{timestamp}_{uuid}.jpg
```

### Presigned URLs
```python
import boto3
from datetime import timedelta

s3_client = boto3.client('s3')

def generate_presigned_url(object_key: str, expires_in: int = 86400):
    """Generate presigned URL valid for 24h"""
    return s3_client.generate_presigned_url(
        'get_object',
        Params={'Bucket': 'famquest-task-photos', 'Key': object_key},
        ExpiresIn=expires_in
    )
```

---

## Environment Variables Required

```bash
# S3 Configuration
AWS_ACCESS_KEY_ID=your_access_key
AWS_SECRET_ACCESS_KEY=your_secret_key
AWS_REGION=us-east-1
S3_BUCKET_NAME=famquest-task-photos

# Photo Upload Limits
MAX_PHOTO_SIZE_MB=5
ALLOWED_MIME_TYPES=image/jpeg,image/png

# Antivirus (ClamAV or VirusTotal)
VIRUS_SCAN_ENABLED=true
VIRUS_SCAN_API_KEY=your_api_key

# Auto-Approval
AUTO_APPROVE_AFTER_HOURS=24
```

---

## Testing Backend Endpoints

### Manual Testing with cURL

```bash
# Upload photo
curl -X POST http://localhost:8000/media/upload \
  -H "Authorization: Bearer $TOKEN" \
  -F "file=@photo.jpg"

# Complete task with photo
curl -X POST http://localhost:8000/tasks/task-123/complete \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "photo_urls": ["https://s3.../photo.jpg"],
    "note": "All done!"
  }'

# Get pending approval tasks
curl -X GET http://localhost:8000/tasks/pending-approval \
  -H "Authorization: Bearer $TOKEN"

# Approve task
curl -X POST http://localhost:8000/tasks/task-123/approve \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "approved": true,
    "quality_rating": 4
  }'

# Create recurring task
curl -X POST http://localhost:8000/tasks/recurring \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Weekly cleaning",
    "rrule": "FREQ=WEEKLY;BYDAY=MO",
    "rotation_strategy": "round_robin",
    "assignee_ids": ["user-1", "user-2"],
    "points": 20
  }'
```

### Integration Tests

```python
# test_photo_upload.py
async def test_photo_upload():
    with open("test_photo.jpg", "rb") as f:
        response = await client.post(
            "/media/upload",
            files={"file": f},
            headers={"Authorization": f"Bearer {token}"}
        )
    assert response.status_code == 200
    assert "url" in response.json()

async def test_complete_task_with_photo():
    response = await client.post(
        f"/tasks/{task_id}/complete",
        json={"photo_urls": [photo_url]},
        headers={"Authorization": f"Bearer {token}"}
    )
    assert response.status_code == 200
    assert response.json()["status"] in ["done", "pending_approval"]

async def test_approve_task():
    response = await client.post(
        f"/tasks/{task_id}/approve",
        json={"approved": True, "quality_rating": 4},
        headers={"Authorization": f"Bearer {token}"}
    )
    assert response.status_code == 200
    assert response.json()["points_awarded"] > 0
```

---

## Database Migrations

### Alembic Migration Script

```python
# migrations/versions/xxx_add_photo_support.py
from alembic import op
import sqlalchemy as sa

def upgrade():
    # Add media table
    op.create_table(
        'media',
        sa.Column('id', sa.UUID(), primary_key=True),
        sa.Column('url', sa.Text(), nullable=False),
        sa.Column('thumbnail_url', sa.Text()),
        sa.Column('file_size_bytes', sa.Integer()),
        sa.Column('mime_type', sa.Text()),
        sa.Column('uploaded_at', sa.DateTime(), server_default=sa.func.now()),
        sa.Column('uploaded_by', sa.UUID(), sa.ForeignKey('users.id')),
        sa.Column('task_id', sa.UUID(), sa.ForeignKey('tasks.id')),
        sa.Column('av_scan_status', sa.Text(), server_default='pending')
    )

    # Add photo columns to tasks
    op.add_column('tasks', sa.Column('proof_photos', sa.ARRAY(sa.Text())))
    op.add_column('tasks', sa.Column('completion_note', sa.Text()))
    op.add_column('tasks', sa.Column('quality_rating', sa.Integer()))

def downgrade():
    op.drop_column('tasks', 'quality_rating')
    op.drop_column('tasks', 'completion_note')
    op.drop_column('tasks', 'proof_photos')
    op.drop_table('media')
```

---

## Deployment Checklist

### Before Deployment
- [ ] S3 bucket created and configured
- [ ] Environment variables set
- [ ] Database migrations run
- [ ] AV scanning configured
- [ ] Cron job scheduled (auto-approval)

### Endpoints to Test
- [ ] POST /media/upload
- [ ] POST /tasks/{id}/complete (with photo_urls)
- [ ] GET /tasks/pending-approval
- [ ] POST /tasks/{id}/approve
- [ ] GET /users/family
- [ ] GET /users/{id}/photos
- [ ] All recurring task endpoints (8 endpoints)

### Security Checks
- [ ] File type validation
- [ ] File size validation (5MB)
- [ ] AV scanning active
- [ ] Presigned URLs expire correctly
- [ ] Parent role verification on approval endpoints

---

## Timeline Estimate

| Task | Estimated Time | Priority |
|------|---------------|----------|
| S3 setup + configuration | 2 hours | High |
| Media upload endpoint | 3 hours | High |
| Enhanced task completion | 2 hours | High |
| Pending approval endpoint | 1 hour | High |
| Approval endpoint | 2 hours | High |
| Auto-approval cron | 1 hour | Medium |
| Family members endpoint | 1 hour | Medium |
| User photos endpoint | 1 hour | Low |
| Testing + debugging | 3 hours | High |
| **TOTAL** | **16 hours** | |

---

## Contact for Questions

**Frontend Developer**: Frontend Architect Agent
**Documentation**:
- `flutter_app/docs/TASKS_RECURRENCE_UI.md`
- `flutter_app/docs/PHOTO_UPLOAD_GUIDE.md`
- `IMPLEMENTATION_SUMMARY.md`

**Backend Developer**: python-expert agent
**Coordination**: This document

---

## Success Criteria

Backend implementation complete when:
1. All 13 endpoints return correct responses
2. S3 photo upload works end-to-end
3. Parent approval workflow functions correctly
4. Recurring task endpoints verified working
5. Integration tests pass
6. Frontend can successfully:
   - Upload photo
   - Complete task with photo
   - View pending approvals
   - Approve/reject tasks
   - Create recurring tasks
   - View occurrences

**Frontend Status**: 100% Ready
**Backend Status**: Awaiting implementation

Deploy backend → Test integration → Production ready
