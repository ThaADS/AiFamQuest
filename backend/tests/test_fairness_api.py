"""
Tests for Fairness API

Covers:
- Family workload distribution
- Fairness score calculation
- Insights generation
- Recommendations
"""

import pytest
from datetime import datetime, timedelta, date
from sqlalchemy.orm import Session
from core.models import User, Family, Task, TaskLog


@pytest.fixture
def test_family_with_users(db: Session):
    """Create family with multiple users"""
    family = Family(
        id="family-fairness",
        name="Fairness Test Family",
        createdAt=datetime.utcnow(),
        updatedAt=datetime.utcnow()
    )
    db.add(family)

    users = []
    for i, role in enumerate(['parent', 'teen', 'child', 'child']):
        user = User(
            id=f"user-{i}",
            familyId=family.id,
            email=f"user{i}@test.com",
            displayName=f"User {i}",
            role=role,
            createdAt=datetime.utcnow(),
            updatedAt=datetime.utcnow()
        )
        db.add(user)
        users.append(user)

    db.commit()
    return family, users


class TestFairnessAPI:
    """Test fairness API endpoints"""

    def test_get_fairness_data(self, client, test_family_with_users, auth_headers, db: Session):
        """Test retrieving fairness data"""
        family, users = test_family_with_users
        parent = users[0]

        response = client.get(
            f"/fairness/family/{family.id}?range=this_week",
            headers=auth_headers(parent.id)
        )

        assert response.status_code == 200
        data = response.json()
        assert 'fairness_score' in data
        assert 'workloads' in data
        assert 'task_distribution' in data
        assert 0.0 <= data['fairness_score'] <= 1.0

    def test_get_fairness_insights(self, client, test_family_with_users, auth_headers, db: Session):
        """Test AI-generated fairness insights"""
        family, users = test_family_with_users
        parent = users[0]
        child = users[2]

        # Create completed tasks for one user
        for i in range(10):
            log = TaskLog(
                id=f"log-{i}",
                taskId=f"task-{i}",
                userId=child.id,
                action='completed',
                metadata={},
                createdAt=datetime.utcnow() - timedelta(days=i % 7)
            )
            db.add(log)
        db.commit()

        response = client.get(
            f"/fairness/insights/{family.id}",
            headers=auth_headers(parent.id)
        )

        assert response.status_code == 200
        data = response.json()
        assert 'insights' in data
        assert isinstance(data['insights'], list)

    def test_get_recommendations(self, client, test_family_with_users, auth_headers):
        """Test fairness recommendations"""
        family, users = test_family_with_users
        parent = users[0]

        response = client.get(
            f"/fairness/recommendations/{family.id}",
            headers=auth_headers(parent.id)
        )

        assert response.status_code == 200
        data = response.json()
        assert 'recommendations' in data
        assert isinstance(data['recommendations'], list)

    def test_fairness_access_control(self, client, test_family_with_users, auth_headers):
        """Test that only family members can access fairness data"""
        family, users = test_family_with_users

        # Create user from different family
        other_user = User(
            id="other-user",
            familyId="other-family",
            email="other@test.com",
            displayName="Other User",
            role="parent",
            createdAt=datetime.utcnow(),
            updatedAt=datetime.utcnow()
        )

        response = client.get(
            f"/fairness/family/{family.id}",
            headers=auth_headers("other-user")
        )

        assert response.status_code == 403

    def test_recommendations_parent_only(self, client, test_family_with_users, auth_headers):
        """Test that only parents can access recommendations"""
        family, users = test_family_with_users
        child = users[2]

        response = client.get(
            f"/fairness/recommendations/{family.id}",
            headers=auth_headers(child.id)
        )

        assert response.status_code == 403
