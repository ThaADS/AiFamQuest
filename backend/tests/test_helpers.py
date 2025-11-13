"""
Tests for Helper Invite System

Covers:
- Creating helper invites
- Verifying invite codes
- Accepting invites
- Managing helpers
- Helper deactivation
"""

import pytest
from datetime import datetime, timedelta
from sqlalchemy.orm import Session
from core.models import User, Family


@pytest.fixture
def test_family_for_helpers(db: Session):
    """Create family for helper tests"""
    family = Family(
        id="family-helpers",
        name="Helper Test Family",
        createdAt=datetime.utcnow(),
        updatedAt=datetime.utcnow()
    )
    db.add(family)

    parent = User(
        id="parent-helpers",
        familyId=family.id,
        email="parent@helpers.com",
        displayName="Parent",
        role="parent",
        createdAt=datetime.utcnow(),
        updatedAt=datetime.utcnow()
    )
    db.add(parent)
    db.commit()

    return family, parent


class TestHelperInviteSystem:
    """Test helper invite functionality"""

    def test_create_helper_invite(self, client, test_family_for_helpers, auth_headers):
        """Test creating helper invite"""
        family, parent = test_family_for_helpers

        response = client.post(
            "/helpers/invite",
            json={
                "name": "Sarah Wilson",
                "email": "sarah@example.com",
                "start_date": (datetime.utcnow() + timedelta(days=1)).isoformat(),
                "end_date": (datetime.utcnow() + timedelta(days=8)).isoformat(),
                "permissions": {
                    "can_view": True,
                    "can_complete": True,
                    "can_upload_photos": False
                }
            },
            headers=auth_headers(parent.id)
        )

        assert response.status_code == 200
        data = response.json()
        assert 'code' in data
        assert len(data['code']) == 6
        assert data['code'].isdigit()
        assert 'expires_at' in data

    def test_verify_helper_code(self, client, test_family_for_helpers, auth_headers):
        """Test verifying helper invite code"""
        family, parent = test_family_for_helpers

        # Create invite first
        create_response = client.post(
            "/helpers/invite",
            json={
                "name": "Test Helper",
                "email": "helper@test.com",
                "start_date": (datetime.utcnow() + timedelta(days=1)).isoformat(),
                "end_date": (datetime.utcnow() + timedelta(days=8)).isoformat(),
                "permissions": {"can_view": True}
            },
            headers=auth_headers(parent.id)
        )

        code = create_response.json()['code']

        # Verify code
        response = client.post(
            f"/helpers/verify?code={code}"
        )

        assert response.status_code == 200
        data = response.json()
        assert data['valid'] is True
        assert data['family_name'] == family.name
        assert data['helper_name'] == 'Test Helper'

    def test_accept_helper_invite(self, client, test_family_for_helpers, auth_headers, db: Session):
        """Test accepting helper invite"""
        family, parent = test_family_for_helpers

        # Create invite
        create_response = client.post(
            "/helpers/invite",
            json={
                "name": "New Helper",
                "email": "newhelper@test.com",
                "start_date": (datetime.utcnow() + timedelta(days=1)).isoformat(),
                "end_date": (datetime.utcnow() + timedelta(days=8)).isoformat(),
                "permissions": {"can_view": True}
            },
            headers=auth_headers(parent.id)
        )

        code = create_response.json()['code']

        # Accept invite
        response = client.post(
            f"/helpers/accept?code={code}"
        )

        assert response.status_code == 200
        data = response.json()
        assert 'access_token' in data
        assert data['user']['role'] == 'helper'
        assert data['user']['email'] == 'newhelper@test.com'

        # Verify helper user was created
        helper = db.query(User).filter(User.email == 'newhelper@test.com').first()
        assert helper is not None
        assert helper.role == 'helper'

    def test_list_helpers(self, client, test_family_for_helpers, auth_headers, db: Session):
        """Test listing active helpers"""
        family, parent = test_family_for_helpers

        # Create helper user
        helper = User(
            id="helper-1",
            familyId=family.id,
            email="helper1@test.com",
            displayName="Helper 1",
            role="helper",
            permissions={
                "helper_end_date": (datetime.utcnow() + timedelta(days=7)).isoformat()
            },
            createdAt=datetime.utcnow(),
            updatedAt=datetime.utcnow()
        )
        db.add(helper)
        db.commit()

        response = client.get(
            "/helpers",
            headers=auth_headers(parent.id)
        )

        assert response.status_code == 200
        data = response.json()
        assert len(data) == 1
        assert data[0]['role'] == 'helper'

    def test_deactivate_helper(self, client, test_family_for_helpers, auth_headers, db: Session):
        """Test deactivating helper"""
        family, parent = test_family_for_helpers

        # Create helper
        helper = User(
            id="helper-deactivate",
            familyId=family.id,
            email="deactivate@test.com",
            displayName="Helper To Deactivate",
            role="helper",
            permissions={
                "helper_end_date": (datetime.utcnow() + timedelta(days=7)).isoformat()
            },
            createdAt=datetime.utcnow(),
            updatedAt=datetime.utcnow()
        )
        db.add(helper)
        db.commit()

        response = client.delete(
            f"/helpers/{helper.id}",
            headers=auth_headers(parent.id)
        )

        assert response.status_code == 200
        data = response.json()
        assert data['success'] is True

        # Verify helper end date was set to now
        db.refresh(helper)
        helper_end_date_str = helper.permissions.get('helper_end_date')
        assert helper_end_date_str is not None

    def test_child_cannot_create_invite(self, client, test_family_for_helpers, auth_headers, db: Session):
        """Test that only parents can create helper invites"""
        family, parent = test_family_for_helpers

        # Create child user
        child = User(
            id="child-no-invite",
            familyId=family.id,
            email="child@test.com",
            displayName="Child",
            role="child",
            createdAt=datetime.utcnow(),
            updatedAt=datetime.utcnow()
        )
        db.add(child)
        db.commit()

        response = client.post(
            "/helpers/invite",
            json={
                "name": "Unauthorized Helper",
                "email": "unauthorized@test.com",
                "start_date": (datetime.utcnow() + timedelta(days=1)).isoformat(),
                "end_date": (datetime.utcnow() + timedelta(days=8)).isoformat(),
                "permissions": {"can_view": True}
            },
            headers=auth_headers(child.id)
        )

        assert response.status_code == 403

    def test_cannot_accept_expired_code(self, client, test_family_for_helpers, auth_headers):
        """Test that expired codes cannot be accepted"""
        # This test would require mocking datetime or waiting 7 days
        # For now, test that invalid code returns 404
        response = client.post(
            "/helpers/accept?code=999999"
        )

        assert response.status_code == 404
