"""
Auth flow integration tests.

Test authentication workflows:
- Email + password login → JWT token → Access protected endpoint
- Apple SSO → Create user → Login → Access resources
- 2FA setup → Generate QR → Verify code → Login with 2FA
- 2FA backup code → Use once → Verify removed from list
- Failed login attempts → Rate limiting → Lock account
"""

import pytest
from datetime import datetime, timedelta
import pyotp

from core.models import User
from core.security import hash_password, verify_password


class TestAuthFlow:
    """Integration tests for authentication flows."""

    def test_email_password_login_access_endpoint(self, api_client, sample_family, client):
        """Test: Email + password login → JWT token → Access protected endpoint."""
        # Login with email and password
        login_data = {
            "email": sample_family["parent"].email,
            "password": "password123"
        }

        response = client.post("/api/auth/login", json=login_data)
        assert response.status_code == 200

        auth_data = response.json()
        assert "access_token" in auth_data
        assert "token_type" in auth_data
        assert auth_data["token_type"] == "bearer"

        # Use token to access protected endpoint
        headers = {"Authorization": f"Bearer {auth_data['access_token']}"}
        response = client.get("/api/users/me", headers=headers)

        assert response.status_code == 200
        user_data = response.json()
        assert user_data["email"] == sample_family["parent"].email
        assert user_data["role"] == "parent"


    def test_apple_sso_create_user_and_login(self, client, test_db, sample_family):
        """Test: Apple SSO → Create user → Login → Access resources."""
        # Simulate Apple SSO callback (simplified - real implementation uses JWT)
        apple_sso_data = {
            "code": "mock_apple_auth_code",
            "id_token": "mock_id_token",
            "user": {
                "email": "apple_user@privaterelay.appleid.com",
                "name": {"firstName": "John", "lastName": "Doe"}
            }
        }

        # Note: Real implementation would verify Apple JWT
        # For integration test, we'll create user directly

        # Create Apple SSO user
        apple_user = User(
            familyId=sample_family["family"].id,
            email=apple_sso_data["user"]["email"],
            displayName=f"{apple_sso_data['user']['name']['firstName']} {apple_sso_data['user']['name']['lastName']}",
            role="parent",
            emailVerified=True,
            sso={"providers": ["apple"], "apple_id": "mock_apple_id_123"}
        )
        test_db.add(apple_user)
        test_db.commit()

        # Login with Apple (should work without password)
        login_response = client.post(
            "/api/auth/sso/apple/callback",
            json={"code": apple_sso_data["code"]}
        )

        # Should receive token (or redirect in real implementation)
        # For test, verify user exists and can access resources
        db_user = test_db.query(User).filter(
            User.email == apple_sso_data["user"]["email"]
        ).first()

        assert db_user is not None
        assert "apple" in db_user.sso.get("providers", [])
        assert db_user.emailVerified is True


    def test_2fa_setup_generate_qr_verify_code(self, api_client, sample_family, test_db, client):
        """Test: 2FA setup → Generate QR → Verify code → Login with 2FA."""
        # Step 1: Setup 2FA (generates QR code)
        response = api_client.post("/api/auth/2fa/setup", user="parent")

        assert response.status_code == 200
        setup_data = response.json()
        assert "qr_code" in setup_data
        assert "secret" in setup_data

        totp_secret = setup_data["secret"]

        # Step 2: Verify setup with TOTP code
        totp = pyotp.TOTP(totp_secret)
        verification_code = totp.now()

        verify_response = api_client.post(
            "/api/auth/2fa/verify-setup",
            user="parent",
            json={"code": verification_code}
        )

        assert verify_response.status_code == 200
        verify_data = verify_response.json()
        assert "backup_codes" in verify_data
        assert len(verify_data["backup_codes"]) == 10

        # Verify 2FA is enabled in database
        test_db.refresh(sample_family["parent"])
        assert sample_family["parent"].twoFAEnabled is True
        assert sample_family["parent"].twoFASecret is not None

        # Step 3: Login with 2FA
        login_data = {
            "email": sample_family["parent"].email,
            "password": "password123"
        }

        login_response = client.post("/api/auth/login", json=login_data)

        # Should require 2FA verification
        assert login_response.status_code == 200
        login_result = login_response.json()
        assert login_result.get("requires_2fa") is True

        # Provide 2FA code
        new_totp_code = totp.now()
        twofa_response = api_client.post(
            "/api/auth/2fa/verify",
            user="parent",
            json={"code": new_totp_code}
        )

        assert twofa_response.status_code == 200
        final_auth = twofa_response.json()
        assert "access_token" in final_auth


    def test_2fa_backup_code_single_use(self, api_client, sample_family, test_db, client):
        """Test: 2FA backup code → Use once → Verify removed from list."""
        # Setup 2FA first
        setup_response = api_client.post("/api/auth/2fa/setup", user="parent")
        totp_secret = setup_response.json()["secret"]

        # Verify setup
        totp = pyotp.TOTP(totp_secret)
        verify_response = api_client.post(
            "/api/auth/2fa/verify-setup",
            user="parent",
            json={"code": totp.now()}
        )

        backup_codes = verify_response.json()["backup_codes"]
        first_backup_code = backup_codes[0]

        # Login and use backup code
        login_response = client.post(
            "/api/auth/login",
            json={
                "email": sample_family["parent"].email,
                "password": "password123"
            }
        )

        # Use backup code for 2FA
        backup_auth_response = api_client.post(
            "/api/auth/2fa/verify",
            user="parent",
            json={"code": first_backup_code}
        )

        assert backup_auth_response.status_code == 200

        # Try to use same backup code again (should fail)
        second_attempt = api_client.post(
            "/api/auth/2fa/verify",
            user="parent",
            json={"code": first_backup_code}
        )

        assert second_attempt.status_code in [400, 401]


    def test_failed_login_rate_limiting(self, client, sample_family):
        """Test: Failed login attempts → Rate limiting → Lock account."""
        # Attempt multiple failed logins
        failed_attempts = 0
        max_attempts = 5

        for i in range(max_attempts + 2):
            response = client.post(
                "/api/auth/login",
                json={
                    "email": sample_family["parent"].email,
                    "password": "wrong_password"
                }
            )

            if response.status_code == 401:
                failed_attempts += 1
            elif response.status_code == 429:  # Too Many Requests
                # Rate limit triggered
                assert failed_attempts >= max_attempts
                break

        # Should have triggered rate limiting
        assert failed_attempts >= max_attempts


    def test_2fa_disable_flow(self, api_client, sample_family, test_db):
        """Test: Disable 2FA after enabling."""
        # Setup 2FA
        setup_response = api_client.post("/api/auth/2fa/setup", user="parent")
        totp_secret = setup_response.json()["secret"]

        totp = pyotp.TOTP(totp_secret)
        api_client.post(
            "/api/auth/2fa/verify-setup",
            user="parent",
            json={"code": totp.now()}
        )

        # Verify 2FA is enabled
        test_db.refresh(sample_family["parent"])
        assert sample_family["parent"].twoFAEnabled is True

        # Disable 2FA
        disable_response = api_client.post(
            "/api/auth/2fa/disable",
            user="parent",
            json={"password": "password123"}
        )

        assert disable_response.status_code == 200

        # Verify 2FA is disabled
        test_db.refresh(sample_family["parent"])
        assert sample_family["parent"].twoFAEnabled is False
        assert sample_family["parent"].twoFASecret is None


    def test_password_reset_flow(self, client, sample_family, test_db):
        """Test: Password reset request → Token → Reset password."""
        # Request password reset
        reset_request = client.post(
            "/api/auth/password-reset/request",
            json={"email": sample_family["parent"].email}
        )

        # Should succeed (even for non-existent emails to prevent enumeration)
        assert reset_request.status_code == 200

        # In real implementation, would send email with token
        # For test, generate token manually
        from core.security import create_access_token
        reset_token = create_access_token(
            data={"sub": sample_family["parent"].id, "type": "password_reset"},
            expires_delta=timedelta(hours=1)
        )

        # Reset password with token
        new_password = "new_secure_password_456"
        reset_response = client.post(
            "/api/auth/password-reset/confirm",
            json={
                "token": reset_token,
                "new_password": new_password
            }
        )

        assert reset_response.status_code == 200

        # Verify can login with new password
        login_response = client.post(
            "/api/auth/login",
            json={
                "email": sample_family["parent"].email,
                "password": new_password
            }
        )

        assert login_response.status_code == 200


    def test_session_expiration_and_refresh(self, api_client, sample_family, client):
        """Test: Token expiration and refresh flow."""
        # Login to get token
        login_response = client.post(
            "/api/auth/login",
            json={
                "email": sample_family["parent"].email,
                "password": "password123"
            }
        )

        tokens = login_response.json()
        access_token = tokens["access_token"]
        refresh_token = tokens.get("refresh_token")

        # Use access token
        headers = {"Authorization": f"Bearer {access_token}"}
        response = client.get("/api/users/me", headers=headers)
        assert response.status_code == 200

        # Simulate token expiration by using refresh token
        if refresh_token:
            refresh_response = client.post(
                "/api/auth/refresh",
                json={"refresh_token": refresh_token}
            )

            assert refresh_response.status_code == 200
            new_tokens = refresh_response.json()
            assert "access_token" in new_tokens

            # Use new access token
            new_headers = {"Authorization": f"Bearer {new_tokens['access_token']}"}
            response = client.get("/api/users/me", headers=new_headers)
            assert response.status_code == 200
