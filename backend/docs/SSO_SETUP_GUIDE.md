# FamQuest SSO Setup Guide

Complete Single Sign-On implementation with Google, Microsoft, Facebook, and Apple.

## Supported Providers

| Provider | Status | Platform Support | Notes |
|----------|--------|-----------------|-------|
| Apple | ✅ Complete | iOS, Android, Web | Required for App Store |
| Google | ✅ Complete | iOS, Android, Web | Most popular |
| Microsoft | ✅ Complete | iOS, Android, Web | Enterprise focus |
| Facebook | ✅ Complete | iOS, Android, Web | Social integration |

## Architecture

### SSO Flow

```
1. User clicks "Sign in with Google"
2. Frontend redirects to /auth/sso/google
3. Backend redirects to Google OAuth
4. User authenticates with Google
5. Google redirects to /auth/sso/google/callback
6. Backend:
   - Verifies OAuth token
   - Creates/updates user
   - Generates JWT
   - Returns JWT to frontend
7. Frontend stores JWT and navigates to app
```

### Database Schema

```python
class User(Base):
    email: str  # Primary identifier
    sso: dict  # JSONB: {"providers": ["google", "apple"], "google_id": "123"}

    # Example SSO field:
    # {
    #     "providers": ["google", "apple"],
    #     "google_id": "123456789",
    #     "apple_id": "001234.abc...",
    #     "microsoft_id": "abc-def-...",
    #     "facebook_id": "987654321"
    # }
```

## Google Sign-In

### 1. Create OAuth Credentials

**Google Cloud Console:**
1. Visit [https://console.cloud.google.com](https://console.cloud.google.com)
2. Create new project: "FamQuest"
3. Enable "Google+ API"
4. Credentials → Create OAuth 2.0 Client ID
5. Application type: Web application
6. Authorized redirect URIs:
   - Development: `http://localhost:8000/auth/sso/google/callback`
   - Production: `https://api.famquest.app/auth/sso/google/callback`
7. Copy Client ID and Client Secret

### 2. Configure Backend

```bash
# .env
GOOGLE_CLIENT_ID=123456789-abc.apps.googleusercontent.com
GOOGLE_CLIENT_SECRET=GOCSPX-abc123...
GOOGLE_REDIRECT_URI=http://localhost:8000/auth/sso/google/callback
```

### 3. Backend Implementation

```python
# backend/routers/auth.py (already implemented)

from authlib.integrations.starlette_client import OAuth

oauth = OAuth()

oauth.register('google',
    client_id=os.getenv('GOOGLE_CLIENT_ID'),
    client_secret=os.getenv('GOOGLE_CLIENT_SECRET'),
    server_metadata_url='https://accounts.google.com/.well-known/openid-configuration',
    client_kwargs={'scope': 'openid email profile'}
)

@router.get("/sso/google")
async def sso_google(request: Request):
    return await oauth.google.authorize_redirect(
        request,
        os.getenv("GOOGLE_REDIRECT_URI")
    )

@router.get("/sso/google/callback")
async def sso_google_cb(request: Request, db: Session = Depends(db)):
    token = await oauth.google.authorize_access_token(request)
    userinfo = token.get('userinfo') or {}
    email = userinfo.get('email')

    if not email:
        raise HTTPException(400, "No email from Google")

    # Find or create user
    user = db.query(User).filter_by(email=email).first()

    if not user:
        # Create new user
        family = Family(id=str(uuid4()), name="Family (Google)")
        user = User(
            id=str(uuid4()),
            familyId=family.id,
            email=email,
            displayName=userinfo.get('name', 'Google User'),
            role="parent",
            sso={"providers": ["google"], "google_id": userinfo.get('sub')}
        )
        db.add(family)
        db.add(user)
        db.commit()
    else:
        # Link Google to existing user
        if "google" not in user.sso.get("providers", []):
            user.sso = {
                **user.sso,
                "providers": user.sso.get("providers", []) + ["google"],
                "google_id": userinfo.get('sub')
            }
            db.commit()

    # Generate JWT
    return {"accessToken": create_jwt(user.id, user.role)}
```

### 4. Frontend Integration (Flutter)

```dart
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  static const apiUrl = 'http://api.famquest.app';

  static Future<String?> signInWithGoogle() async {
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn(
        scopes: ['email', 'profile'],
      );

      final GoogleSignInAccount? account = await googleSignIn.signIn();
      if (account == null) return null;

      final GoogleSignInAuthentication auth = await account.authentication;

      // Send ID token to backend
      final response = await http.post(
        Uri.parse('$apiUrl/auth/sso/google'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'id_token': auth.idToken}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['accessToken'];
      }

      return null;
    } catch (e) {
      print('Google Sign-In Error: $e');
      return null;
    }
  }
}
```

## Microsoft Sign-In

### 1. Register Application

**Azure Portal:**
1. Visit [https://portal.azure.com](https://portal.azure.com)
2. Azure Active Directory → App registrations → New registration
3. Name: "FamQuest"
4. Supported account types: "Personal Microsoft accounts only"
5. Redirect URI:
   - Type: Web
   - URI: `https://api.famquest.app/auth/sso/microsoft/callback`
6. Copy Application (client) ID
7. Certificates & secrets → New client secret → Copy secret value

### 2. Configure Backend

```bash
# .env
MICROSOFT_CLIENT_ID=abc-def-123-456
MICROSOFT_CLIENT_SECRET=xyz789~...
MICROSOFT_REDIRECT_URI=http://localhost:8000/auth/sso/microsoft/callback
```

### 3. Backend Implementation

Already implemented in `backend/routers/auth.py`:

```python
oauth.register('microsoft',
    client_id=os.getenv('MICROSOFT_CLIENT_ID'),
    client_secret=os.getenv('MICROSOFT_CLIENT_SECRET'),
    server_metadata_url='https://login.microsoftonline.com/common/v2.0/.well-known/openid-configuration',
    client_kwargs={'scope': 'openid email profile'}
)

@router.get("/sso/microsoft")
async def sso_ms(request: Request):
    return await oauth.microsoft.authorize_redirect(
        request,
        os.getenv("MICROSOFT_REDIRECT_URI")
    )

@router.get("/sso/microsoft/callback")
async def sso_ms_cb(request: Request, db: Session = Depends(db)):
    token = await oauth.microsoft.authorize_access_token(request)
    userinfo = token.get('userinfo') or {}
    email = userinfo.get('email') or userinfo.get('preferred_username')

    # ... (same flow as Google)
```

## Facebook Sign-In

### 1. Create Facebook App

**Meta for Developers:**
1. Visit [https://developers.facebook.com/apps](https://developers.facebook.com/apps)
2. Create App → Consumer → Continue
3. App name: "FamQuest"
4. Settings → Basic → Copy App ID and App Secret
5. Add Product → Facebook Login
6. Valid OAuth Redirect URIs:
   - `https://api.famquest.app/auth/sso/facebook/callback`

### 2. Configure Backend

```bash
# .env
FACEBOOK_CLIENT_ID=123456789012345
FACEBOOK_CLIENT_SECRET=abc123def456...
FACEBOOK_REDIRECT_URI=http://localhost:8000/auth/sso/facebook/callback
```

### 3. Backend Implementation

Already implemented in `backend/routers/auth.py`:

```python
oauth.register('facebook',
    client_id=os.getenv('FACEBOOK_CLIENT_ID'),
    client_secret=os.getenv('FACEBOOK_CLIENT_SECRET'),
    access_token_url='https://graph.facebook.com/v12.0/oauth/access_token',
    authorize_url='https://www.facebook.com/v12.0/dialog/oauth',
    api_base_url='https://graph.facebook.com',
    client_kwargs={'scope': 'email'}
)

@router.get("/sso/facebook")
async def sso_fb(request: Request):
    return await oauth.facebook.authorize_redirect(
        request,
        os.getenv("FACEBOOK_REDIRECT_URI")
    )

@router.get("/sso/facebook/callback")
async def sso_fb_cb(request: Request, db: Session = Depends(db)):
    token = await oauth.facebook.authorize_access_token(request)

    async with oauth.facebook.get('me?fields=id,name,email', token=token) as resp:
        data = await resp.json()

    email = data.get('email') or f"{data.get('id')}@facebook.local"

    # ... (same flow as Google)
```

## Apple Sign-In

### 1. Configure Apple Developer Account

**Apple Developer Portal:**
1. Visit [https://developer.apple.com/account](https://developer.apple.com/account)
2. Certificates, IDs & Profiles → Keys → Create new key
3. Enable "Sign in with Apple"
4. Download `.p8` private key file (save securely)
5. Note Key ID (10 characters)
6. Note Team ID (from membership page, 10 characters)

**Create Service ID:**
1. Identifiers → App IDs → Register new identifier
2. Select "Services IDs" → Continue
3. Description: "FamQuest Web"
4. Identifier: `com.famquest.app` (Service ID)
5. Enable "Sign in with Apple"
6. Configure → Add domain: `famquest.app`
7. Return URLs: `https://api.famquest.app/auth/sso/apple/callback`

### 2. Configure Backend

```bash
# .env
APPLE_CLIENT_ID=com.famquest.app  # Service ID (not App ID)
APPLE_TEAM_ID=ABCD123456  # 10-character Team ID
APPLE_KEY_ID=ABCD123456  # 10-character Key ID from .p8 file
APPLE_PRIVATE_KEY=-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----
APPLE_REDIRECT_URI=http://localhost:8000/auth/sso/apple/callback
```

### 3. Backend Implementation

Already implemented in `backend/routers/auth.py`:

```python
@router.post("/sso/apple/callback")
def sso_apple_cb(req: AppleSignInReq, db: Session = Depends(db)):
    """
    Apple Sign-In callback (receives ID token from client)
    Handles private relay emails and first-time user info
    """
    client_id = os.getenv("APPLE_CLIENT_ID")

    # Verify Apple ID token
    payload = verify_apple_jwt(req.id_token, client_id)
    if not payload:
        raise HTTPException(401, "Invalid Apple ID token")

    apple_id = payload.get("sub")
    email = payload.get("email")

    # Find or create user
    user = db.query(User).filter_by(email=email).first()

    if not user:
        # Extract name from user_info (only provided on first sign-in)
        display_name = "Apple User"
        if req.user_info:
            first_name = req.user_info.get("name", {}).get("firstName", "")
            last_name = req.user_info.get("name", {}).get("lastName", "")
            if first_name or last_name:
                display_name = f"{first_name} {last_name}".strip()

        family = Family(id=str(uuid4()), name="Family (Apple)")
        user = User(
            id=str(uuid4()),
            familyId=family.id,
            email=email,
            displayName=display_name,
            role="parent",
            sso={"providers": ["apple"], "apple_id": apple_id}
        )
        db.add(family)
        db.add(user)
        db.commit()

    return {"accessToken": create_jwt(user.id, user.role)}
```

## Frontend Implementation

### Flutter SSO Buttons

```dart
import 'package:flutter/material.dart';

class SSOButtons extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Apple Sign-In (iOS priority)
        if (Platform.isIOS)
          SignInWithAppleButton(
            onPressed: () => AuthService.signInWithApple(),
          ),

        // Google Sign-In
        ElevatedButton.icon(
          icon: Image.asset('assets/google_icon.png', height: 24),
          label: Text('Sign in with Google'),
          onPressed: () => AuthService.signInWithGoogle(),
        ),

        // Microsoft Sign-In
        ElevatedButton.icon(
          icon: Image.asset('assets/microsoft_icon.png', height: 24),
          label: Text('Sign in with Microsoft'),
          onPressed: () => AuthService.signInWithMicrosoft(),
        ),

        // Facebook Sign-In
        ElevatedButton.icon(
          icon: Icon(Icons.facebook, color: Colors.blue),
          label: Text('Sign in with Facebook'),
          onPressed: () => AuthService.signInWithFacebook(),
        ),
      ],
    );
  }
}
```

## Testing

### Test SSO Flow

```bash
# 1. Start backend
cd backend
uvicorn main:app --reload

# 2. Test Google SSO
open http://localhost:8000/auth/sso/google

# 3. Test Microsoft SSO
open http://localhost:8000/auth/sso/microsoft

# 4. Test Facebook SSO
open http://localhost:8000/auth/sso/facebook
```

### Test with Postman

**Google OAuth:**
1. GET `http://localhost:8000/auth/sso/google`
2. Follow redirect to Google login
3. After callback, copy JWT token
4. Use token in Authorization header: `Bearer <token>`

## Security Considerations

### 1. Verify OAuth Tokens

Always verify tokens server-side:

```python
# Verify Google ID token
from google.oauth2 import id_token
from google.auth.transport import requests

idinfo = id_token.verify_oauth2_token(
    token,
    requests.Request(),
    GOOGLE_CLIENT_ID
)
```

### 2. Handle Private Relay Emails

Apple users may use private relay emails:

```python
# Example: abc123@privaterelay.appleid.com

# Don't send emails to private relay (Apple forwards)
# Store apple_id as primary identifier
user.sso = {"apple_id": payload["sub"], "providers": ["apple"]}
```

### 3. Link Multiple SSO Providers

Allow users to link multiple providers:

```python
# User already has Google, now adding Apple
if user.email == apple_email:
    user.sso = {
        **user.sso,
        "providers": user.sso.get("providers", []) + ["apple"],
        "apple_id": apple_id
    }
    db.commit()
```

### 4. Rate Limit SSO Endpoints

```python
from slowapi import Limiter

limiter = Limiter(key_func=get_remote_address)

@router.get("/sso/google")
@limiter.limit("10/minute")
async def sso_google(request: Request):
    # ...
```

## Troubleshooting

### Google: "redirect_uri_mismatch"

Check authorized redirect URIs in Google Cloud Console match exactly:

```bash
# Development
GOOGLE_REDIRECT_URI=http://localhost:8000/auth/sso/google/callback

# Production
GOOGLE_REDIRECT_URI=https://api.famquest.app/auth/sso/google/callback
```

### Microsoft: "invalid_client"

Ensure client secret hasn't expired:

1. Azure Portal → App registrations → Your app
2. Certificates & secrets → Check expiration
3. Generate new secret if expired

### Facebook: "Can't Load URL"

Check Valid OAuth Redirect URIs in Facebook App Settings:

1. Meta for Developers → Your app → Settings → Basic
2. Add Platform → Website
3. Site URL: `https://famquest.app`

### Apple: "invalid_client"

Verify Service ID configuration:

1. Apple Developer → Identifiers → Services IDs
2. Check "Sign in with Apple" is enabled
3. Verify domain and return URLs

## Roadmap

### Phase 1 (Complete)
- ✅ Google Sign-In
- ✅ Microsoft Sign-In
- ✅ Facebook Sign-In
- ✅ Apple Sign-In

### Phase 2 (Q1 2026)
- [ ] GitHub Sign-In (developer audience)
- [ ] Twitter/X Sign-In (social integration)
- [ ] LinkedIn Sign-In (professional network)

### Phase 3 (Q2 2026)
- [ ] SSO account linking UI
- [ ] Multiple provider management
- [ ] Provider preference settings
- [ ] SSO analytics dashboard
