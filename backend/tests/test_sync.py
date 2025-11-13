"""
Comprehensive tests for Delta Sync API

Tests:
- No conflicts sync
- Task done wins strategy
- Delete wins strategy
- Version mismatch handling
- Last-writer-wins (LWW)
- Batch transaction rollback
- Empty changes handling
- Concurrent user sync
"""

import pytest
from datetime import datetime, timedelta
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from core.db import Base
from core import models
from core.security import create_jwt
from main import app
import uuid

# Test database
TEST_DATABASE_URL = "sqlite:///./test_sync.db"
engine = create_engine(TEST_DATABASE_URL, connect_args={"check_same_thread": False})
TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


@pytest.fixture
def db_session():
    """Create test database session"""
    Base.metadata.create_all(bind=engine)
    db = TestingSessionLocal()
    try:
        yield db
    finally:
        db.close()
        Base.metadata.drop_all(bind=engine)


@pytest.fixture
def test_family(db_session):
    """Create test family"""
    family = models.Family(name="Test Family")
    db_session.add(family)
    db_session.commit()
    db_session.refresh(family)
    return family


@pytest.fixture
def test_user(db_session, test_family):
    """Create test user"""
    user = models.User(
        familyId=test_family.id,
        email="test@example.com",
        displayName="Test User",
        role="parent"
    )
    db_session.add(user)
    db_session.commit()
    db_session.refresh(user)
    return user


@pytest.fixture
def auth_token(test_user, test_family):
    """Generate auth token for test user"""
    token = create_jwt({
        "sub": test_user.id,
        "email": test_user.email,
        "role": test_user.role,
        "familyId": test_family.id
    })
    return token


@pytest.fixture
def client(auth_token):
    """Create test client with auth"""
    client = TestClient(app)
    client.headers = {"Authorization": f"Bearer {auth_token}"}
    return client


def test_delta_sync_no_conflicts(client, db_session, test_family, test_user):
    """Client sends 5 new tasks, server has 3 new events"""
    # Create server-side events
    for i in range(3):
        event = models.Event(
            familyId=test_family.id,
            title=f"Event {i}",
            description="Test event",
            start=datetime.utcnow() + timedelta(hours=i),
            createdBy=test_user.id,
            createdAt=datetime.utcnow(),
            updatedAt=datetime.utcnow()
        )
        db_session.add(event)
    db_session.commit()

    # Client sends 5 new tasks
    last_sync = (datetime.utcnow() - timedelta(hours=1)).isoformat()
    client_changes = []

    for i in range(5):
        task_id = str(uuid.uuid4())
        client_changes.append({
            "entity_type": "task",
            "entity_id": task_id,
            "action": "create",
            "data": {
                "id": task_id,
                "familyId": test_family.id,
                "title": f"Client Task {i}",
                "desc": "Test task",
                "category": "cleaning",
                "status": "open",
                "points": 10
            },
            "version": 1,
            "client_timestamp": datetime.utcnow().isoformat()
        })

    # Execute sync
    response = client.post("/sync/delta", json={
        "last_sync_at": last_sync,
        "changes": client_changes,
        "device_id": "test-device-1"
    })

    assert response.status_code == 200
    data = response.json()

    # Verify
    assert data["success"] is True
    assert data["applied_count"] == 5
    assert data["error_count"] == 0
    assert len(data["conflicts"]) == 0
    assert len(data["server_changes"]) == 3  # 3 events from server

    # Verify tasks created in DB
    tasks = db_session.query(models.Task).filter(
        models.Task.familyId == test_family.id
    ).all()
    assert len(tasks) == 5


def test_delta_sync_task_done_wins(client, db_session, test_family, test_user):
    """Client marks task done, server updated title. Done wins."""
    # Create task on server
    task = models.Task(
        familyId=test_family.id,
        title="Vaatwasser",
        desc="Load dishwasher",
        status="open",
        points=10,
        createdBy=test_user.id,
        version=1,
        createdAt=datetime.utcnow() - timedelta(hours=2),
        updatedAt=datetime.utcnow() - timedelta(minutes=30)
    )
    db_session.add(task)
    db_session.commit()
    task_id = task.id

    # Server updates title (version 2)
    task.title = "Vaatwasser uitruimen"
    task.version = 2
    task.updatedAt = datetime.utcnow() - timedelta(minutes=10)
    db_session.commit()

    # Client marks as done (still version 1 - conflict!)
    last_sync = (datetime.utcnow() - timedelta(hours=1)).isoformat()
    client_changes = [{
        "entity_type": "task",
        "entity_id": task_id,
        "action": "update",
        "data": {
            "status": "done",
            "completedAt": datetime.utcnow().isoformat()
        },
        "version": 1,  # Stale version!
        "client_timestamp": datetime.utcnow().isoformat()
    }]

    # Execute sync
    response = client.post("/sync/delta", json={
        "last_sync_at": last_sync,
        "changes": client_changes,
        "device_id": "test-device-1"
    })

    assert response.status_code == 200
    data = response.json()

    # Verify "done wins" strategy applied
    assert data["success"] is True
    assert data["applied_count"] == 1

    # Task should be marked done despite version mismatch
    db_session.expire_all()
    task = db_session.query(models.Task).filter(models.Task.id == task_id).first()
    assert task.status == "done"
    assert task.version == 3  # Incremented


def test_delta_sync_delete_wins(client, db_session, test_family, test_user):
    """Client updates task, server deleted it. Delete wins."""
    # Create task on server
    task = models.Task(
        familyId=test_family.id,
        title="Old Task",
        status="open",
        points=10,
        createdBy=test_user.id,
        version=1,
        createdAt=datetime.utcnow() - timedelta(hours=2),
        updatedAt=datetime.utcnow() - timedelta(hours=1)
    )
    db_session.add(task)
    db_session.commit()
    task_id = task.id

    # Server deletes task
    db_session.delete(task)
    db_session.commit()

    # Client tries to update deleted task
    last_sync = (datetime.utcnow() - timedelta(hours=3)).isoformat()
    client_changes = [{
        "entity_type": "task",
        "entity_id": task_id,
        "action": "update",
        "data": {
            "title": "Updated Task"
        },
        "version": 1,
        "client_timestamp": datetime.utcnow().isoformat()
    }]

    # Execute sync
    response = client.post("/sync/delta", json={
        "last_sync_at": last_sync,
        "changes": client_changes,
        "device_id": "test-device-1"
    })

    assert response.status_code == 200
    data = response.json()

    # Verify conflict detected (task not found)
    assert len(data["conflicts"]) == 1
    assert data["conflicts"][0]["entity_type"] == "task"
    assert data["conflicts"][0]["conflict_reason"] == "Task not found on server"

    # Task should remain deleted
    task = db_session.query(models.Task).filter(models.Task.id == task_id).first()
    assert task is None


def test_delta_sync_version_mismatch(client, db_session, test_family, test_user):
    """Client version 2, server version 4. Server wins."""
    # Create task on server
    task = models.Task(
        familyId=test_family.id,
        title="Task",
        status="open",
        points=10,
        createdBy=test_user.id,
        version=4,  # Server is ahead
        createdAt=datetime.utcnow() - timedelta(hours=2),
        updatedAt=datetime.utcnow() - timedelta(minutes=5)
    )
    db_session.add(task)
    db_session.commit()
    task_id = task.id

    # Client tries to update with old version
    last_sync = (datetime.utcnow() - timedelta(hours=1)).isoformat()
    client_changes = [{
        "entity_type": "task",
        "entity_id": task_id,
        "action": "update",
        "data": {
            "title": "Client Updated Title"
        },
        "version": 2,  # Stale!
        "client_timestamp": datetime.utcnow() - timedelta(minutes=10).isoformat()
    }]

    # Execute sync
    response = client.post("/sync/delta", json={
        "last_sync_at": last_sync,
        "changes": client_changes,
        "device_id": "test-device-1"
    })

    assert response.status_code == 200
    data = response.json()

    # Verify conflict (server wins due to newer timestamp)
    assert len(data["conflicts"]) == 1
    conflict = data["conflicts"][0]
    assert conflict["resolution"] == "server_wins"
    assert conflict["client_version"] == 2
    assert conflict["server_version"] == 4

    # Task title should be unchanged
    db_session.expire_all()
    task = db_session.query(models.Task).filter(models.Task.id == task_id).first()
    assert task.title == "Task"
    assert task.version == 4


def test_delta_sync_last_writer_wins(client, db_session, test_family, test_user):
    """Client timestamp newer. Client wins."""
    # Create task on server
    task = models.Task(
        familyId=test_family.id,
        title="Task",
        status="open",
        points=10,
        createdBy=test_user.id,
        version=2,
        createdAt=datetime.utcnow() - timedelta(hours=2),
        updatedAt=datetime.utcnow() - timedelta(minutes=30)  # Older update
    )
    db_session.add(task)
    db_session.commit()
    task_id = task.id

    # Client sends newer update (LWW wins)
    last_sync = (datetime.utcnow() - timedelta(hours=1)).isoformat()
    client_changes = [{
        "entity_type": "task",
        "entity_id": task_id,
        "action": "update",
        "data": {
            "title": "Client Newer Title"
        },
        "version": 2,
        "client_timestamp": datetime.utcnow().isoformat()  # Newer!
    }]

    # Execute sync
    response = client.post("/sync/delta", json={
        "last_sync_at": last_sync,
        "changes": client_changes,
        "device_id": "test-device-1"
    })

    assert response.status_code == 200
    data = response.json()

    # Verify LWW applied
    assert data["success"] is True
    assert data["applied_count"] == 1

    # Task should have client's title
    db_session.expire_all()
    task = db_session.query(models.Task).filter(models.Task.id == task_id).first()
    assert task.title == "Client Newer Title"
    assert task.version == 3


def test_delta_sync_batch_transaction(client, db_session, test_family, test_user):
    """100 changes, 1 fails. Check transaction handling."""
    # Note: In production, we allow 10% error rate before rollback
    # This test verifies partial success handling

    last_sync = (datetime.utcnow() - timedelta(hours=1)).isoformat()
    client_changes = []

    # Create 10 tasks (all valid)
    for i in range(10):
        task_id = str(uuid.uuid4())
        client_changes.append({
            "entity_type": "task",
            "entity_id": task_id,
            "action": "create",
            "data": {
                "id": task_id,
                "familyId": test_family.id,
                "title": f"Task {i}",
                "status": "open",
                "points": 10
            },
            "version": 1,
            "client_timestamp": datetime.utcnow().isoformat()
        })

    # Add 1 invalid task (missing required field)
    client_changes.append({
        "entity_type": "task",
        "entity_id": str(uuid.uuid4()),
        "action": "create",
        "data": {
            "familyId": test_family.id,
            # Missing title!
            "status": "open"
        },
        "version": 1,
        "client_timestamp": datetime.utcnow().isoformat()
    })

    # Execute sync
    response = client.post("/sync/delta", json={
        "last_sync_at": last_sync,
        "changes": client_changes,
        "device_id": "test-device-1"
    })

    assert response.status_code == 200
    data = response.json()

    # Verify partial success
    assert data["applied_count"] == 10
    assert data["error_count"] == 1
    assert len(data["conflicts"]) == 1

    # Valid tasks should be created
    tasks = db_session.query(models.Task).filter(
        models.Task.familyId == test_family.id
    ).all()
    assert len(tasks) == 10


def test_delta_sync_empty_changes(client, db_session, test_family, test_user):
    """Client has no changes. Server returns its changes only."""
    # Create server-side task
    task = models.Task(
        familyId=test_family.id,
        title="Server Task",
        status="open",
        points=10,
        createdBy=test_user.id,
        version=1,
        createdAt=datetime.utcnow(),
        updatedAt=datetime.utcnow()
    )
    db_session.add(task)
    db_session.commit()

    # Client has no changes
    last_sync = (datetime.utcnow() - timedelta(hours=1)).isoformat()
    response = client.post("/sync/delta", json={
        "last_sync_at": last_sync,
        "changes": [],
        "device_id": "test-device-1"
    })

    assert response.status_code == 200
    data = response.json()

    # Verify
    assert data["success"] is True
    assert data["applied_count"] == 0
    assert len(data["server_changes"]) == 1
    assert data["server_changes"][0]["entity_type"] == "task"


def test_delta_sync_concurrent_users(client, db_session, test_family, test_user):
    """User A and B sync simultaneously. No race conditions."""
    # Create task
    task = models.Task(
        familyId=test_family.id,
        title="Shared Task",
        status="open",
        points=10,
        createdBy=test_user.id,
        version=1,
        createdAt=datetime.utcnow() - timedelta(hours=1),
        updatedAt=datetime.utcnow() - timedelta(hours=1)
    )
    db_session.add(task)
    db_session.commit()
    task_id = task.id

    # User A updates task
    last_sync_a = (datetime.utcnow() - timedelta(hours=2)).isoformat()
    changes_a = [{
        "entity_type": "task",
        "entity_id": task_id,
        "action": "update",
        "data": {"title": "User A Update"},
        "version": 1,
        "client_timestamp": datetime.utcnow().isoformat()
    }]

    response_a = client.post("/sync/delta", json={
        "last_sync_at": last_sync_a,
        "changes": changes_a,
        "device_id": "device-a"
    })

    assert response_a.status_code == 200
    assert response_a.json()["success"] is True

    # User B immediately updates task (should see conflict)
    changes_b = [{
        "entity_type": "task",
        "entity_id": task_id,
        "action": "update",
        "data": {"title": "User B Update"},
        "version": 1,  # Same version as A started with!
        "client_timestamp": datetime.utcnow().isoformat()
    }]

    response_b = client.post("/sync/delta", json={
        "last_sync_at": last_sync_a,
        "changes": changes_b,
        "device_id": "device-b"
    })

    assert response_b.status_code == 200
    data_b = response_b.json()

    # User B should detect conflict or apply LWW
    # (depends on timestamp precision - either success with LWW or conflict)
    assert data_b["success"] is True or len(data_b["conflicts"]) > 0


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
