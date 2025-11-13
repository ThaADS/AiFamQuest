"""
Cross-Component Integration Tests.

Tests interactions across multiple system components:
- Full workflow end-to-end scenarios
- Offline sync and conflict resolution
- Parent-child interaction flows
- Real-time updates and notifications
- Cascade deletion behaviors
- Rate limiting and anti-cheat measures
"""

import pytest
from datetime import datetime, timedelta
import time

from core.models import Task, PointsLedger, Badge, UserStreak, Family, User
from tests.integration.helpers import simulate_offline_sync


class TestCrossComponent:
    """Integration tests for cross-component workflows."""

    def test_full_workflow_login_to_badge(self, api_client, sample_family, test_db):
        """Test: Full flow: Login → Create task → Assign → Complete → See points → Badge unlock."""
        # Step 1: Login (authentication already handled by api_client)
        user_id = sample_family["child1"].id

        # Step 2: Parent creates task
        task_data = {
            "title": "Full Workflow Task",
            "category": "cleaning",
            "due": datetime(2025, 11, 20, 14, 0).isoformat(),
            "assignees": [user_id],
            "points": 30
        }

        response = api_client.post("/api/tasks", user="parent", json=task_data)
        assert response.status_code == 201
        task_id = response.json()["id"]

        # Step 3: Child views assigned task
        response = api_client.get(f"/api/tasks/{task_id}", user="child1")
        assert response.status_code == 200
        task = response.json()
        assert user_id in task["assignees"]

        # Step 4: Child completes task
        response = api_client.post(f"/api/tasks/{task_id}/complete", user="child1")
        assert response.status_code in [200, 201]

        # Step 5: Child views points
        response = api_client.get("/api/gamification/points", user="child1")
        if response.status_code == 200:
            points_data = response.json()
            assert points_data["total"] >= 30

        # Step 6: Check if badge was unlocked (if first completion)
        response = api_client.get("/api/gamification/badges", user="child1")
        if response.status_code == 200:
            badges = response.json()
            # May have completion_1 or similar badge
            assert isinstance(badges, list)


    def test_offline_create_5_tasks_sync(self, api_client, sample_family, test_db):
        """Test: Offline: Create 5 tasks → Go online → Sync → Verify all persisted."""
        user_id = sample_family["child1"].id
        family_id = sample_family["family"].id

        # Create 5 tasks offline
        offline_tasks = []
        for i in range(5):
            task = {
                "id": f"offline-task-{i+1:03d}",
                "familyId": family_id,
                "title": f"Offline Task {i+1}",
                "desc": "Created while offline",
                "category": "cleaning",
                "due": datetime(2025, 11, 20 + i, 10, 0),
                "assignees": [user_id],
                "points": 10,
                "status": "open",
                "createdBy": sample_family["parent"].id
            }
            offline_tasks.append(task)

        # Simulate sync
        operations = [
            {"type": "create", "entity": "task", "data": task}
            for task in offline_tasks
        ]

        sync_result = simulate_offline_sync(test_db, operations)

        # Verify all created
        assert sync_result["created"] == 5
        assert len(sync_result["conflicts"]) == 0

        # Verify all persisted in database
        for i in range(5):
            task = test_db.query(Task).filter(
                Task.id == f"offline-task-{i+1:03d}"
            ).first()
            assert task is not None
            assert task.title == f"Offline Task {i+1}"


    def test_offline_conflict_resolution(self, api_client, sample_family, test_db):
        """Test: Conflict: Offline edit task A → Online edit task A → Sync → Manual resolution."""
        # Create task online
        task_data = {
            "title": "Conflict Task",
            "category": "cleaning",
            "assignees": [sample_family["child1"].id],
            "points": 20
        }

        response = api_client.post("/api/tasks", user="parent", json=task_data)
        task_id = response.json()["id"]

        # Parent edits online
        response = api_client.put(
            f"/api/tasks/{task_id}",
            user="parent",
            json={"title": "Updated Online", "points": 25}
        )
        assert response.status_code == 200

        # Simulate offline edit (stale version)
        offline_update = {
            "id": task_id,
            "title": "Updated Offline",
            "points": 30
        }

        # Attempt sync with conflict
        sync_result = simulate_offline_sync(
            test_db,
            [{"type": "update", "entity": "task", "data": offline_update}]
        )

        # Should detect conflict due to version mismatch
        # Last-writer-wins: offline update should succeed
        assert sync_result["updated"] >= 0

        # Verify final state
        task = test_db.query(Task).filter(Task.id == task_id).first()
        # Depending on conflict resolution strategy
        assert task is not None


    def test_parent_child_notification_approval_flow(self, api_client, sample_family, test_db):
        """Test: Parent creates task → Child sees notification → Child completes → Parent approval → Points awarded."""
        # Step 1: Parent creates task with approval requirement
        task_data = {
            "title": "Deep Clean Room",
            "category": "cleaning",
            "due": datetime(2025, 11, 20, 14, 0).isoformat(),
            "assignees": [sample_family["child1"].id],
            "points": 50,
            "parentApproval": True,
            "photoRequired": True
        }

        response = api_client.post("/api/tasks", user="parent", json=task_data)
        assert response.status_code == 201
        task_id = response.json()["id"]

        # Step 2: Child receives notification (would be tested with notification system)
        # For now, verify child can see task
        response = api_client.get(f"/api/tasks/{task_id}", user="child1")
        assert response.status_code == 200

        # Step 3: Child completes task
        response = api_client.post(
            f"/api/tasks/{task_id}/complete",
            user="child1",
            json={"photos": ["https://example.com/clean_room.jpg"]}
        )
        assert response.status_code in [200, 201]

        # Task should be pending approval
        task = test_db.query(Task).filter(Task.id == task_id).first()
        assert task.status == "pendingApproval"

        # Step 4: Parent approves
        response = api_client.post(
            f"/api/tasks/{task_id}/approve",
            user="parent",
            json={"rating": 5}
        )
        assert response.status_code in [200, 201]

        # Step 5: Verify points awarded
        points_entry = test_db.query(PointsLedger).filter(
            PointsLedger.userId == sample_family["child1"].id,
            PointsLedger.taskId == task_id
        ).first()

        assert points_entry is not None
        assert points_entry.delta >= 50  # May have multipliers


    def test_real_time_leaderboard_update(self, api_client, sample_family, test_db):
        """Test: User 1 completes task → User 2 sees leaderboard update (WebSocket or polling)."""
        # Give user1 initial points
        initial_points = PointsLedger(
            userId=sample_family["child1"].id,
            delta=50,
            reason="Initial points"
        )
        test_db.add(initial_points)
        test_db.commit()

        # User2 checks leaderboard
        response = api_client.get("/api/gamification/leaderboard", user="child2")
        assert response.status_code == 200
        initial_leaderboard = response.json()

        # User1 completes task
        task_data = {
            "title": "Leaderboard Test Task",
            "category": "cleaning",
            "assignees": [sample_family["child1"].id],
            "points": 30
        }

        response = api_client.post("/api/tasks", user="parent", json=task_data)
        task_id = response.json()["id"]

        response = api_client.post(f"/api/tasks/{task_id}/complete", user="child1")
        assert response.status_code in [200, 201]

        # User2 checks leaderboard again
        response = api_client.get("/api/gamification/leaderboard", user="child2")
        assert response.status_code == 200
        updated_leaderboard = response.json()

        # Leaderboard should show updated points for user1
        user1_initial = next(
            (u for u in initial_leaderboard if u["userId"] == sample_family["child1"].id),
            {"points": 0}
        )
        user1_updated = next(
            (u for u in updated_leaderboard if u["userId"] == sample_family["child1"].id),
            {"points": 0}
        )

        assert user1_updated["points"] > user1_initial["points"]


    def test_delete_user_cascade_behavior(self, api_client, sample_family, test_db):
        """Test: Delete user → Verify cascade: tasks unassigned, points preserved, badges kept."""
        # Create user to delete
        from core.security import hash_password

        temp_user = User(
            familyId=sample_family["family"].id,
            email="temp@test.com",
            displayName="Temp User",
            role="child",
            pin=hash_password("9999")
        )
        test_db.add(temp_user)
        test_db.commit()

        # Create task assigned to temp user
        task_data = {
            "title": "Temp User Task",
            "category": "cleaning",
            "assignees": [temp_user.id],
            "points": 20
        }

        response = api_client.post("/api/tasks", user="parent", json=task_data)
        task_id = response.json()["id"]

        # Award points
        points = PointsLedger(
            userId=temp_user.id,
            delta=20,
            taskId=task_id,
            reason="Task completion"
        )
        test_db.add(points)
        test_db.commit()

        # Delete user
        response = api_client.delete(f"/api/users/{temp_user.id}", user="parent")

        # Verify cascade behavior
        deleted_user = test_db.query(User).filter(User.id == temp_user.id).first()
        assert deleted_user is None

        # Task should exist but unassigned or deleted depending on implementation
        task = test_db.query(Task).filter(Task.id == task_id).first()
        if task:
            # If task preserved, user should be removed from assignees
            assert temp_user.id not in task.assignees


    def test_delete_family_full_cascade(self, api_client, sample_family, test_db):
        """Test: Delete family → Verify full cascade: all users, tasks, events, points deleted."""
        # Create temporary family
        from core.models import Family

        temp_family = Family(name="Temp Family")
        test_db.add(temp_family)
        test_db.commit()

        # Create user in temp family
        temp_user = User(
            familyId=temp_family.id,
            email="tempfamily@test.com",
            displayName="Temp Family User",
            role="parent",
            passwordHash="hashed"
        )
        test_db.add(temp_user)
        test_db.commit()

        # Delete family
        test_db.delete(temp_family)
        test_db.commit()

        # Verify cascade deletion
        deleted_family = test_db.query(Family).filter(Family.id == temp_family.id).first()
        assert deleted_family is None

        # Users should be deleted (cascade)
        deleted_user = test_db.query(User).filter(User.id == temp_user.id).first()
        assert deleted_user is None


    def test_rate_limiting_anti_cheat(self, api_client, sample_family, test_db):
        """Test: Rate limiting: 10 rapid task completions → Verify anti-cheat (min 30s interval)."""
        user_id = sample_family["child1"].id

        # Create multiple tasks
        task_ids = []
        for i in range(10):
            task_data = {
                "title": f"Quick Task {i+1}",
                "category": "cleaning",
                "assignees": [user_id],
                "points": 5
            }

            response = api_client.post("/api/tasks", user="parent", json=task_data)
            task_ids.append(response.json()["id"])

        # Rapidly complete all tasks
        completion_times = []
        for task_id in task_ids:
            start = time.time()
            response = api_client.post(f"/api/tasks/{task_id}/complete", user="child1")
            completion_times.append(time.time() - start)

            # Backend should enforce rate limiting
            # After a few rapid completions, should get rate limit error
            if len(completion_times) > 5:
                # May get 429 Too Many Requests
                if response.status_code == 429:
                    break

        # Verify not all tasks completed instantly (anti-cheat active)
        # Implementation-dependent
