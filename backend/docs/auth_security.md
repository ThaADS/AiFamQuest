# Authentication & Security Documentation

**FamQuest Backend Security Implementation**
**Version:** 2.1
**Last Updated:** 2025-11-11

---

## Table of Contents

1. [Overview](#overview)
2. [SSO Provider Setup](#sso-provider-setup)
3. [Two-Factor Authentication (2FA)](#two-factor-authentication-2fa)
4. [Security Best Practices](#security-best-practices)
5. [Rate Limiting](#rate-limiting)
6. [Backup Code Management](#backup-code-management)
7. [Audit Logging](#audit-logging)
8. [Testing](#testing)

---

## Overview

FamQuest implements a comprehensive authentication system with:

- **Email/Password Login** with bcrypt password hashing
- **SSO Providers:** Apple, Google, Microsoft, Facebook
- **Two-Factor Authentication (2FA):** TOTP-based with backup codes
- **Rate Limiting:** Protection against brute force attacks
- **Audit Logging:** Complete security event tracking
- **Session Management:** JWT-based with configurable expiration

### Security Priorities

1. **Zero Trust:** Never trust client input, always validate server-side
2. **Defense in Depth:** Multiple layers of security controls
3. **Principle of Least Privilege:** Grant minimum necessary permissions
4. **Audit Everything:** Log all security-relevant events
5. **Privacy by Design:** Minimize PII, encrypt sensitive data

---

## SSO Provider Setup

### Apple Sign-In (REQUIRED for iOS App Store)

Apple Sign-In is mandatory for iOS App Store approval when other social logins are offered.

#### Configuration

1. **Apple Developer Account Setup:**
   - Go to [Apple Developer Console](https://developer.apple.com/account/)
   - Create an App ID with "Sign in with Apple" capability
   - Create a Service ID for web/backend authentication
   - Generate a private key (.p8 file) for JWT signing

2. **Environment Variables:**
   ```bash
   APPLE_CLIENT_ID=com.famquest.app  # Service ID
   APPLE_TEAM_ID=ABCD123456          # Team ID from Apple Developer
   APPLE_KEY_ID=ABCD123456           # Key ID from generated .p8 key
   APPLE_PRIVATE_KEY=|-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----|
   APPLE_REDIRECT_URI=https://api.famquest.app/auth/sso/apple/callback
   ```

3. **Implementation Details:**
   - Client (iOS) receives `authorization_code` and `id_token` from Apple
   - Client sends to backend `/auth/sso/apple/callback`
   - Backend verifies `id_token` signature with Apple's public keys
   - User info only provided on first sign-in (cache displayName)
   - Private relay emails (`@privaterelay.appleid.com`) fully supported

#### Private Relay Email Handling

Apple provides users with private relay emails to protect their real email addresses. Implementation:

```python
# Backend handles both real and relay emails transparently
email = payload.get("email")  # Could be real or @privaterelay.appleid.com
apple_id = payload.get("sub")  # Unique Apple user ID

# Store apple_id in user.sso for account linking
user.sso = {"providers": ["apple"], "apple_id": apple_id}
```

#### First Sign-In User Info

Apple only provides `user_info` (name, email) on the first sign-in:

```json
{
  "id_token": "eyJhbGc...",
  "user_info": {
    "name": {"firstName": "John", "lastName": "Doe"},
    "email": "john@privaterelay.appleid.com"
  }
}
```

**IMPORTANT:** Backend must store `displayName` on first sign-in, as subsequent logins won't include this data.

### Google Sign-In

1. **Google Cloud Console:**
   - Create OAuth 2.0 Client ID
   - Add authorized redirect URIs

2. **Environment Variables:**
   ```bash
   GOOGLE_CLIENT_ID=123456789.apps.googleusercontent.com
   GOOGLE_CLIENT_SECRET=GOCSPX-xxxxx
   GOOGLE_REDIRECT_URI=https://api.famquest.app/auth/sso/google/callback
   ```

### Microsoft Sign-In

1. **Azure Portal:**
   - Register application in Azure AD
   - Configure redirect URIs

2. **Environment Variables:**
   ```bash
   MICROSOFT_CLIENT_ID=abcd1234-5678-90ef-ghij-klmnopqrstuv
   MICROSOFT_CLIENT_SECRET=xxx~xxxxx
   MICROSOFT_REDIRECT_URI=https://api.famquest.app/auth/sso/microsoft/callback
   ```

### Facebook Sign-In

1. **Facebook Developers:**
   - Create app in Facebook Developer Console
   - Add Facebook Login product

2. **Environment Variables:**
   ```bash
   FACEBOOK_CLIENT_ID=123456789012345
   FACEBOOK_CLIENT_SECRET=abcdef1234567890
   FACEBOOK_REDIRECT_URI=https://api.famquest.app/auth/sso/facebook/callback
   ```

---

## Two-Factor Authentication (2FA)

FamQuest implements TOTP-based 2FA compatible with Google Authenticator, Authy, 1Password, and other authenticator apps.

### 2FA Setup Flow

#### 1. Initiate Setup (POST `/auth/2fa/setup`)

**Request:**
```bash
curl -X POST https://api.famquest.app/auth/2fa/setup \
  -H "Authorization: Bearer <jwt_token>"
```

**Response:**
```json
{
  "secret": "JBSWY3DPEHPK3PXP",
  "otpauth_url": "otpauth://totp/FamQuest:user@example.com?secret=JBSWY3DPEHPK3PXP&issuer=FamQuest",
  "qr_code_url": "data:image/png;base64,iVBORw0KGgo..."
}
```

- **secret:** TOTP secret (base32 encoded)
- **otpauth_url:** URI for manual entry
- **qr_code_url:** QR code as data URL for scanning

#### 2. Verify Setup (POST `/auth/2fa/verify-setup`)

User scans QR code with authenticator app and enters the 6-digit code.

**Request:**
```bash
curl -X POST https://api.famquest.app/auth/2fa/verify-setup \
  -H "Authorization: Bearer <jwt_token>" \
  -H "Content-Type: application/json" \
  -d '{
    "secret": "JBSWY3DPEHPK3PXP",
    "code": "123456"
  }'
```

**Response:**
```json
{
  "success": true,
  "backup_codes": [
    "ABCD1234",
    "EFGH5678",
    "IJKL9012",
    ...
  ],
  "message": "2FA enabled successfully. Save these backup codes in a secure location"
}
```

**CRITICAL:** User must save backup codes immediately. They are shown only once.

#### 3. Database Updates

On successful verification:
- `user.twoFAEnabled` → `true`
- `user.twoFASecret` → encrypted TOTP secret
- `user.permissions.backupCodes` → array of hashed backup codes
- Audit log entry created: `action="2fa_enabled"`
- Email notification sent (TODO: implement)

### 2FA Login Flow

#### Option A: Login with OTP (POST `/auth/login`)

```bash
curl -X POST https://api.famquest.app/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "user@example.com",
    "password": "SecurePass123!",
    "otp": "123456"
  }'
```

#### Option B: Separate Verification (POST `/auth/2fa/verify`)

```bash
# Step 1: Attempt login (returns 401 if 2FA required)
curl -X POST https://api.famquest.app/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "user@example.com",
    "password": "SecurePass123!"
  }'

# Step 2: Verify 2FA code
curl -X POST https://api.famquest.app/auth/2fa/verify \
  -H "Content-Type: application/json" \
  -d '{
    "email": "user@example.com",
    "password": "SecurePass123!",
    "code": "123456"
  }'
```

### TOTP Time Window

TOTP codes are valid for **30 seconds** with **±1 time step tolerance** (total 90-second window):

- Current 30s window: Valid
- Previous 30s window: Valid
- Next 30s window: Valid
- Older/newer: Invalid

This accommodates clock drift between client and server.

### Backup Codes

#### Purpose

Backup codes provide emergency access if:
- User loses authenticator device
- Authenticator app uninstalled
- Phone broken/stolen

#### Characteristics

- **10 codes** generated per user
- **8 characters** each (uppercase hex)
- **Single-use:** Code deleted after successful use
- **Hashed storage:** SHA-256 (not bcrypt for speed)
- **Regeneration:** User can generate new set anytime

#### Usage

```bash
curl -X POST https://api.famquest.app/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "user@example.com",
    "password": "SecurePass123!",
    "otp": "ABCD1234"  # Backup code instead of TOTP
  }'
```

#### Regeneration (POST `/auth/2fa/backup-codes`)

```bash
curl -X POST https://api.famquest.app/auth/2fa/backup-codes \
  -H "Authorization: Bearer <jwt_token>"
```

**Response:**
```json
{
  "backup_codes": ["NEW11111", "NEW22222", ...],
  "message": "New backup codes generated. Previous codes are now invalid"
}
```

### 2FA Disable (POST `/auth/2fa/disable`)

**Requirements:**
- Current password
- Current TOTP code OR backup code

**Request:**
```bash
curl -X POST https://api.famquest.app/auth/2fa/disable \
  -H "Authorization: Bearer <jwt_token>" \
  -H "Content-Type: application/json" \
  -d '{
    "password": "SecurePass123!",
    "code": "123456"
  }'
```

**Database Updates:**
- `user.twoFAEnabled` → `false`
- `user.twoFASecret` → `null`
- `user.permissions.backupCodes` → removed
- Audit log entry created: `action="2fa_disabled"`
- Email notification sent (TODO: implement)

---

## Security Best Practices

### Password Requirements

**Minimum:** 8 characters, 1 uppercase, 1 lowercase, 1 digit, 1 special character
**Recommended:** 12+ characters, passphrase-style

**Implementation:**
```python
import re

def validate_password(password: str) -> bool:
    if len(password) < 8:
        return False
    if not re.search(r'[A-Z]', password):
        return False
    if not re.search(r'[a-z]', password):
        return False
    if not re.search(r'\d', password):
        return False
    if not re.search(r'[!@#$%^&*(),.?":{}|<>]', password):
        return False
    return True
```

### JWT Token Management

**Configuration:**
```bash
JWT_SECRET=<strong_random_secret>  # Generate with: openssl rand -base64 32
JWT_ISS=FamQuest
JWT_AUD=famquest.app
JWT_EXP_MIN=60  # Token expires after 60 minutes
```

**Payload:**
```json
{
  "iss": "FamQuest",
  "aud": "famquest.app",
  "iat": 1699699200,
  "exp": 1699702800,
  "sub": "user_uuid",
  "role": "parent"
}
```

**Best Practices:**
- **Never log JWT tokens** in plain text
- **Rotate JWT_SECRET** regularly (monthly recommended)
- **Use HTTPS only** - tokens sent in Authorization header
- **Client storage:** flutter_secure_storage (encrypted)
- **Refresh tokens:** TODO for Phase 2

### Sensitive Data Handling

**At-Rest Encryption:**
- Database: PostgreSQL with encryption at rest
- Device: flutter_secure_storage with platform keychain/keystore
- Backups: Encrypted with AES-256

**In-Transit Encryption:**
- TLS 1.2+ required
- HTTPS-only (enforce with HSTS)
- Certificate pinning recommended for mobile apps

**PII Minimization:**
- Only collect necessary user data
- Pseudonymize data sent to AI services
- Scrub logs of PII before storage

---

## Rate Limiting

### Implementation

FamQuest implements in-memory rate limiting (MVP). Production should use Redis.

**Current Limits:**
- **Login attempts:** 5 attempts per 15 minutes per email
- **2FA verification:** 5 attempts per 15 minutes per email
- **Password reset:** 3 attempts per hour per email (TODO)

### How It Works

```python
# Rate limiting key format
rate_key = f"login:{email}"

# Check rate limit before processing
if not check_rate_limit(rate_key, max_attempts=5, window_minutes=15):
    raise HTTPException(429, "Too many login attempts. Please try again in 15 minutes")

# Reset on successful auth
reset_rate_limit(rate_key)
```

### Storage

**In-Memory (Current):**
```python
_rate_limit_store: Dict[str, List[float]] = {}
# Key: rate_key, Value: list of timestamps
```

**Redis (Production):**
```python
import redis
r = redis.Redis.from_url(os.getenv("REDIS_URL"))

def check_rate_limit(key: str, max_attempts: int, window_seconds: int) -> bool:
    now = time.time()
    window_start = now - window_seconds

    # Remove old attempts
    r.zremrangebyscore(key, 0, window_start)

    # Count attempts in window
    count = r.zcard(key)
    if count >= max_attempts:
        return False

    # Add new attempt
    r.zadd(key, {now: now})
    r.expire(key, window_seconds)
    return True
```

### Response Format

**429 Too Many Requests:**
```json
{
  "detail": "Too many login attempts. Please try again in 15 minutes"
}
```

---

## Backup Code Management

### Storage Format

```python
# Example user.permissions structure
{
  "backupCodes": [
    "a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2",  # SHA-256 hash
    "b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2c3",
    ...
  ],
  "childCanCreateTasks": true,
  "childCanCreateStudyItems": false
}
```

### Security Considerations

1. **Hashing Algorithm:** SHA-256 (not bcrypt)
   - Rationale: Speed for brute force prevention less critical than TOTP
   - Backup codes are 8 chars (32 bits entropy) - sufficient for single-use

2. **Single-Use Enforcement:**
   - Code removed from array after successful use
   - User cannot reuse same code

3. **User Education:**
   - Display warning: "Save these codes in a secure location"
   - Suggest: Password manager, encrypted note, printed copy in safe

4. **Regeneration Policy:**
   - User can regenerate anytime (authenticated)
   - Old codes immediately invalidated
   - Audit log entry created

---

## Audit Logging

### Logged Events

**Authentication:**
- `login_success` - Successful login (email, SSO)
- `login_failed` - Failed login attempt
- `2fa_enabled` - User enabled 2FA
- `2fa_disabled` - User disabled 2FA
- `backup_codes_regenerated` - New backup codes generated
- `password_changed` - Password updated
- `sso_linked` - SSO provider linked to account

**Authorization:**
- `permission_granted` - New permission assigned
- `permission_revoked` - Permission removed
- `role_changed` - User role updated

**Critical Actions:**
- `family_deleted` - Family and all data deleted
- `user_deleted` - User account deleted
- `data_export` - User requested data export (GDPR)

### Audit Log Schema

```python
class AuditLog(Base):
    __tablename__ = "audit_log"

    id: str  # UUID
    actorUserId: str  # Who performed the action
    familyId: str  # Which family (for multi-tenant isolation)
    action: str  # Event type (see above)
    meta: Dict  # Additional context (JSON)
    createdAt: datetime  # When it happened
```

### Example Entries

```json
{
  "id": "uuid-1234",
  "actorUserId": "user-uuid",
  "familyId": "family-uuid",
  "action": "login_success",
  "meta": {
    "method": "email",
    "twoFA": true,
    "ip": "192.168.1.1",
    "userAgent": "Mozilla/5.0..."
  },
  "createdAt": "2025-11-11T10:30:00Z"
}
```

```json
{
  "id": "uuid-5678",
  "actorUserId": "user-uuid",
  "familyId": "family-uuid",
  "action": "2fa_enabled",
  "meta": {},
  "createdAt": "2025-11-11T10:35:00Z"
}
```

### Querying Audit Logs

```python
# Get user's recent security events
logs = db.query(AuditLog).filter_by(
    actorUserId=user_id
).order_by(
    AuditLog.createdAt.desc()
).limit(50).all()

# Get family's activity (parent view)
logs = db.query(AuditLog).filter_by(
    familyId=family_id
).filter(
    AuditLog.createdAt >= datetime.utcnow() - timedelta(days=30)
).all()
```

---

## Testing

### Running Security Tests

```bash
# Run all security tests
pytest backend/tests/test_auth_security.py -v

# Run specific test category
pytest backend/tests/test_auth_security.py::test_2fa_setup_success -v

# Run with coverage
pytest backend/tests/test_auth_security.py --cov=routers.auth --cov-report=html
```

### Test Coverage

**Target:** 90% code coverage for authentication/security modules

**Current Tests:** 20+ test cases covering:
- Login with/without 2FA
- Rate limiting
- 2FA setup/verification/disable
- Backup code usage
- Apple Sign-In
- Audit logging
- Security utilities

### Manual Testing Checklist

**2FA Flow:**
- [ ] User can enable 2FA with Google Authenticator
- [ ] User can enable 2FA with Authy
- [ ] QR code scans correctly
- [ ] TOTP codes accepted within ±1 time window
- [ ] Backup codes work as fallback
- [ ] Used backup codes cannot be reused
- [ ] User can regenerate backup codes
- [ ] User can disable 2FA
- [ ] Email notifications sent (when implemented)

**Apple Sign-In:**
- [ ] New user sign-in creates account
- [ ] Existing user (by email) links Apple account
- [ ] Private relay emails work
- [ ] User info captured on first sign-in
- [ ] Subsequent sign-ins work without user_info
- [ ] App Store submission approved

**Rate Limiting:**
- [ ] Login blocked after 5 failed attempts
- [ ] 2FA verification blocked after 5 attempts
- [ ] Rate limit resets after 15 minutes
- [ ] Successful auth resets rate limit

**Security:**
- [ ] Passwords hashed with bcrypt
- [ ] JWT tokens signed with HS256
- [ ] Tokens expire after configured time
- [ ] Authorization header required for protected endpoints
- [ ] Audit logs created for security events

---

## Deployment Checklist

### Pre-Production

- [ ] Generate strong JWT_SECRET (`openssl rand -base64 32`)
- [ ] Configure all SSO providers (Apple, Google, MS, Facebook)
- [ ] Set up production database with encryption
- [ ] Enable HTTPS with valid SSL certificate
- [ ] Configure Redis for rate limiting
- [ ] Set up email service for notifications
- [ ] Test Apple Sign-In with TestFlight
- [ ] Run full security test suite
- [ ] Penetration testing completed
- [ ] OWASP MASVS compliance verified

### Production

- [ ] Monitor audit logs for suspicious activity
- [ ] Set up alerts for high rate limit hits
- [ ] Regular JWT_SECRET rotation (monthly)
- [ ] Backup code usage monitoring
- [ ] Failed login attempt tracking
- [ ] 2FA adoption metrics
- [ ] Apple Sign-In success rate monitoring

---

## Security Contact

**Report vulnerabilities:** security@famquest.app
**Response time:** 24 hours for critical issues
**Bug bounty program:** Coming soon

---

**Last Review:** 2025-11-11
**Next Review:** 2025-12-11
**Reviewers:** Security Team, Backend Team
