from fastapi import APIRouter, Depends, HTTPException, Request, Response
from fastapi.responses import JSONResponse
from sqlalchemy.orm import Session
from uuid import uuid4
from core.db import SessionLocal, Base, engine
from core import models
from core.schemas import (
    LoginReq, RegisterReq, TokenRes, UserOut,
    TwoFASetupRes, TwoFAVerifySetupReq, TwoFAVerifySetupRes,
    TwoFAVerifyReq, TwoFADisableReq, BackupCodesRes,
    AppleSignInReq
)
from core.security import (
    hash_password, verify_password, create_jwt,
    new_totp_secret, verify_totp, generate_totp_uri, generate_qr_code,
    generate_backup_codes, hash_backup_code, verify_backup_code,
    check_rate_limit, reset_rate_limit, verify_apple_jwt
)
from authlib.integrations.starlette_client import OAuth
import os
import base64
from datetime import datetime
from typing import Optional

Base.metadata.create_all(bind=engine)
router = APIRouter()
oauth = OAuth()

# Google
oauth.register('google',
    client_id=os.getenv('GOOGLE_CLIENT_ID'),
    client_secret=os.getenv('GOOGLE_CLIENT_SECRET'),
    server_metadata_url='https://accounts.google.com/.well-known/openid-configuration',
    client_kwargs={'scope':'openid email profile'}
)
# Microsoft
oauth.register('microsoft',
    client_id=os.getenv('MICROSOFT_CLIENT_ID'),
    client_secret=os.getenv('MICROSOFT_CLIENT_SECRET'),
    server_metadata_url='https://login.microsoftonline.com/common/v2.0/.well-known/openid-configuration',
    client_kwargs={'scope':'openid email profile'}
)
# Facebook (OAuth 2)
oauth.register('facebook',
    client_id=os.getenv('FACEBOOK_CLIENT_ID'),
    client_secret=os.getenv('FACEBOOK_CLIENT_SECRET'),
    access_token_url='https://graph.facebook.com/v12.0/oauth/access_token',
    authorize_url='https://www.facebook.com/v12.0/dialog/oauth',
    api_base_url='https://graph.facebook.com',
    client_kwargs={'scope':'email'}
)

def db():
    d = SessionLocal()
    try: yield d
    finally: d.close()

def get_current_user(request: Request, d: Session = Depends(db)) -> models.User:
    """Extract user from JWT token in Authorization header"""
    auth_header = request.headers.get("Authorization")
    if not auth_header or not auth_header.startswith("Bearer "):
        raise HTTPException(401, "Missing or invalid authorization header")

    token = auth_header.split(" ")[1]
    try:
        import jwt
        payload = jwt.decode(token, os.getenv("JWT_SECRET", "dev_secret"), algorithms=["HS256"])
        user_id = payload.get("sub")
        if not user_id:
            raise HTTPException(401, "Invalid token payload")

        user = d.query(models.User).filter_by(id=user_id).first()
        if not user:
            raise HTTPException(401, "User not found")

        return user
    except jwt.ExpiredSignatureError:
        raise HTTPException(401, "Token expired")
    except jwt.InvalidTokenError:
        raise HTTPException(401, "Invalid token")

@router.post("/register", response_model=UserOut)
def register(req: RegisterReq, d: Session = Depends(db)):
    fam = models.Family(id=str(uuid4()), name=req.familyName)
    user = models.User(id=str(uuid4()), familyId=fam.id, email=req.email, displayName=req.displayName, role="parent", passwordHash=hash_password(req.password))
    d.add(fam); d.add(user); d.commit()
    return UserOut(id=user.id,familyId=user.familyId,email=user.email,displayName=user.displayName,role=user.role,locale='nl',theme='minimal')

@router.post("/login", response_model=TokenRes)
def login(req: LoginReq, d: Session = Depends(db)):
    """Login with email/password, with optional 2FA verification"""
    # Rate limiting
    rate_key = f"login:{req.email}"
    if not check_rate_limit(rate_key, max_attempts=5, window_minutes=15):
        raise HTTPException(429, "Too many login attempts. Please try again in 15 minutes")

    user = d.query(models.User).filter_by(email=req.email).first()
    if not user or not verify_password(req.password, user.passwordHash):
        raise HTTPException(401, "Invalid credentials")

    # Check 2FA requirement
    if user.twoFAEnabled:
        if not req.otp:
            raise HTTPException(401, "2FA code required")

        # Verify TOTP or backup code
        totp_valid = verify_totp(user.twoFASecret, req.otp)
        backup_valid = False

        if not totp_valid and user.permissions.get("backupCodes"):
            # Check backup codes
            backup_codes = user.permissions.get("backupCodes", [])
            for idx, hashed_code in enumerate(backup_codes):
                if verify_backup_code(req.otp, hashed_code):
                    backup_valid = True
                    # Remove used backup code
                    backup_codes.pop(idx)
                    user.permissions = {**user.permissions, "backupCodes": backup_codes}
                    d.commit()
                    break

        if not totp_valid and not backup_valid:
            raise HTTPException(401, "Invalid 2FA code")

    # Log audit event
    audit = models.AuditLog(
        id=str(uuid4()),
        actorUserId=user.id,
        familyId=user.familyId,
        action="login_success",
        meta={"method": "email", "twoFA": user.twoFAEnabled}
    )
    d.add(audit)
    d.commit()

    # Reset rate limit on successful login
    reset_rate_limit(rate_key)

    return TokenRes(accessToken=create_jwt(user.id, user.role))

# ===== 2FA Endpoints =====

@router.post("/2fa/setup", response_model=TwoFASetupRes)
def setup_2fa(request: Request, d: Session = Depends(db)):
    """
    Generate TOTP secret and QR code for 2FA setup
    User must verify with code before 2FA is enabled
    """
    user = get_current_user(request, d)

    secret = new_totp_secret()
    otpauth_url = generate_totp_uri(secret, user.email)

    # Generate QR code as data URL
    qr_bytes = generate_qr_code(otpauth_url)
    qr_data_url = f"data:image/png;base64,{base64.b64encode(qr_bytes).decode()}"

    return TwoFASetupRes(
        secret=secret,
        otpauth_url=otpauth_url,
        qr_code_url=qr_data_url
    )

@router.post("/2fa/verify-setup", response_model=TwoFAVerifySetupRes)
def verify_2fa_setup(req: TwoFAVerifySetupReq, request: Request, d: Session = Depends(db)):
    """
    Verify TOTP code during setup and enable 2FA
    Returns backup codes for user to save
    """
    user = get_current_user(request, d)

    # Verify TOTP code
    if not verify_totp(req.secret, req.code):
        raise HTTPException(400, "Invalid verification code")

    # Generate backup codes
    backup_codes = generate_backup_codes(10)
    hashed_codes = [hash_backup_code(code) for code in backup_codes]

    # Enable 2FA
    user.twoFAEnabled = True
    user.twoFASecret = req.secret
    user.permissions = {**user.permissions, "backupCodes": hashed_codes}
    d.commit()

    # Log audit event
    audit = models.AuditLog(
        id=str(uuid4()),
        actorUserId=user.id,
        familyId=user.familyId,
        action="2fa_enabled",
        meta={}
    )
    d.add(audit)
    d.commit()

    # TODO: Send email notification to user

    return TwoFAVerifySetupRes(
        success=True,
        backup_codes=backup_codes,
        message="2FA enabled successfully. Save these backup codes in a secure location"
    )

@router.post("/2fa/verify", response_model=TokenRes)
def verify_2fa(req: TwoFAVerifyReq, d: Session = Depends(db)):
    """
    Verify 2FA code during login
    Alternative to passing OTP in login request
    """
    # Rate limiting
    rate_key = f"2fa:{req.email}"
    if not check_rate_limit(rate_key, max_attempts=5, window_minutes=15):
        raise HTTPException(429, "Too many verification attempts")

    user = d.query(models.User).filter_by(email=req.email).first()
    if not user or not verify_password(req.password, user.passwordHash):
        raise HTTPException(401, "Invalid credentials")

    if not user.twoFAEnabled:
        raise HTTPException(400, "2FA not enabled for this account")

    # Verify TOTP or backup code
    totp_valid = verify_totp(user.twoFASecret, req.code)
    backup_valid = False

    if not totp_valid and user.permissions.get("backupCodes"):
        backup_codes = user.permissions.get("backupCodes", [])
        for idx, hashed_code in enumerate(backup_codes):
            if verify_backup_code(req.code, hashed_code):
                backup_valid = True
                backup_codes.pop(idx)
                user.permissions = {**user.permissions, "backupCodes": backup_codes}
                d.commit()
                break

    if not totp_valid and not backup_valid:
        raise HTTPException(401, "Invalid 2FA code")

    # Reset rate limit
    reset_rate_limit(rate_key)

    return TokenRes(accessToken=create_jwt(user.id, user.role))

@router.post("/2fa/disable")
def disable_2fa(req: TwoFADisableReq, request: Request, d: Session = Depends(db)):
    """
    Disable 2FA (requires password + current TOTP code)
    """
    user = get_current_user(request, d)

    # Verify password
    if not verify_password(req.password, user.passwordHash):
        raise HTTPException(401, "Invalid password")

    # Verify 2FA code
    if not user.twoFAEnabled:
        raise HTTPException(400, "2FA not enabled")

    totp_valid = verify_totp(user.twoFASecret, req.code)
    backup_valid = False

    if not totp_valid and user.permissions.get("backupCodes"):
        backup_codes = user.permissions.get("backupCodes", [])
        for hashed_code in backup_codes:
            if verify_backup_code(req.code, hashed_code):
                backup_valid = True
                break

    if not totp_valid and not backup_valid:
        raise HTTPException(401, "Invalid 2FA code")

    # Disable 2FA
    user.twoFAEnabled = False
    user.twoFASecret = None
    user.permissions = {k: v for k, v in user.permissions.items() if k != "backupCodes"}
    d.commit()

    # Log audit event
    audit = models.AuditLog(
        id=str(uuid4()),
        actorUserId=user.id,
        familyId=user.familyId,
        action="2fa_disabled",
        meta={}
    )
    d.add(audit)
    d.commit()

    # TODO: Send email notification

    return {"success": True, "message": "2FA disabled successfully"}

@router.post("/2fa/backup-codes", response_model=BackupCodesRes)
def regenerate_backup_codes(request: Request, d: Session = Depends(db)):
    """
    Generate new backup codes (invalidates old ones)
    """
    user = get_current_user(request, d)

    if not user.twoFAEnabled:
        raise HTTPException(400, "2FA not enabled")

    # Generate new backup codes
    backup_codes = generate_backup_codes(10)
    hashed_codes = [hash_backup_code(code) for code in backup_codes]

    user.permissions = {**user.permissions, "backupCodes": hashed_codes}
    d.commit()

    # Log audit event
    audit = models.AuditLog(
        id=str(uuid4()),
        actorUserId=user.id,
        familyId=user.familyId,
        action="backup_codes_regenerated",
        meta={}
    )
    d.add(audit)
    d.commit()

    return BackupCodesRes(
        backup_codes=backup_codes,
        message="New backup codes generated. Previous codes are now invalid"
    )

@router.get("/sso/google")
async def sso_google(request: Request):
    return await oauth.google.authorize_redirect(request, os.getenv("GOOGLE_REDIRECT_URI"))
@router.get("/sso/google/callback", response_model=TokenRes)
async def sso_google_cb(request: Request, d: Session = Depends(db)):
    token = await oauth.google.authorize_access_token(request)
    userinfo = token.get('userinfo') or {}
    email = userinfo.get('email')
    if not email: raise HTTPException(400,"No email from Google")
    user = d.query(models.User).filter_by(email=email).first()
    if not user:
        fam = models.Family(id=str(uuid4()), name="Family (Google)")
        user = models.User(id=str(uuid4()), familyId=fam.id, email=email, displayName=userinfo.get('name','Google User'), role="parent")
        d.add(fam); d.add(user); d.commit()
    return TokenRes(accessToken=create_jwt(user.id, user.role))

@router.get("/sso/microsoft")
async def sso_ms(request: Request):
    return await oauth.microsoft.authorize_redirect(request, os.getenv("MICROSOFT_REDIRECT_URI"))
@router.get("/sso/microsoft/callback", response_model=TokenRes)
async def sso_ms_cb(request: Request, d: Session = Depends(db)):
    token = await oauth.microsoft.authorize_access_token(request)
    userinfo = token.get('userinfo') or {}
    email = userinfo.get('email') or userinfo.get('preferred_username')
    if not email: raise HTTPException(400,"No email from Microsoft")
    user = d.query(models.User).filter_by(email=email).first()
    if not user:
        fam = models.Family(id=str(uuid4()), name="Family (MS)")
        user = models.User(id=str(uuid4()), familyId=fam.id, email=email, displayName=userinfo.get('name','MS User'), role="parent")
        d.add(fam); d.add(user); d.commit()
    return TokenRes(accessToken=create_jwt(user.id, user.role))

# ===== Apple Sign-In =====

@router.post("/sso/apple/callback", response_model=TokenRes)
def sso_apple_cb(req: AppleSignInReq, d: Session = Depends(db)):
    """
    Apple Sign-In callback (receives ID token from client)
    Handles private relay emails and first-time user info
    """
    client_id = os.getenv("APPLE_CLIENT_ID")
    if not client_id:
        raise HTTPException(500, "Apple Sign-In not configured")

    # Verify Apple ID token
    payload = verify_apple_jwt(req.id_token, client_id)
    if not payload:
        raise HTTPException(401, "Invalid Apple ID token")

    apple_id = payload.get("sub")
    email = payload.get("email")

    if not apple_id or not email:
        raise HTTPException(400, "Missing required claims from Apple")

    # Check if user exists (by email OR by apple_id in SSO)
    user = d.query(models.User).filter_by(email=email).first()

    # If not found by email, check by apple_id
    if not user:
        users = d.query(models.User).all()
        for u in users:
            if u.sso.get("apple_id") == apple_id:
                user = u
                break

    # Create new user if first sign-in
    if not user:
        # Extract name from user_info (only provided on first sign-in)
        display_name = "Apple User"
        if req.user_info:
            first_name = req.user_info.get("name", {}).get("firstName", "")
            last_name = req.user_info.get("name", {}).get("lastName", "")
            if first_name or last_name:
                display_name = f"{first_name} {last_name}".strip()

        fam = models.Family(id=str(uuid4()), name="Family (Apple)")
        user = models.User(
            id=str(uuid4()),
            familyId=fam.id,
            email=email,
            displayName=display_name,
            role="parent",
            sso={"providers": ["apple"], "apple_id": apple_id}
        )
        d.add(fam)
        d.add(user)
        d.commit()
    else:
        # Link Apple account to existing user
        if "apple" not in user.sso.get("providers", []):
            user.sso = {
                **user.sso,
                "providers": user.sso.get("providers", []) + ["apple"],
                "apple_id": apple_id
            }
            d.commit()

    # Log audit event
    audit = models.AuditLog(
        id=str(uuid4()),
        actorUserId=user.id,
        familyId=user.familyId,
        action="login_success",
        meta={"method": "apple_sso", "apple_id": apple_id}
    )
    d.add(audit)
    d.commit()

    return TokenRes(accessToken=create_jwt(user.id, user.role))

# ===== Facebook SSO =====

@router.get("/sso/facebook")
async def sso_fb(request: Request):
    return await oauth.facebook.authorize_redirect(request, os.getenv("FACEBOOK_REDIRECT_URI"))

@router.get("/sso/facebook/callback", response_model=TokenRes)
async def sso_fb_cb(request: Request, d: Session = Depends(db)):
    token = await oauth.facebook.authorize_access_token(request)
    async with oauth.facebook.get('me?fields=id,name,email', token=token) as resp:
        data = await resp.json()
    email = data.get('email') or f"{data.get('id')}@facebook.local"
    user = d.query(models.User).filter_by(email=email).first()
    if not user:
        fam = models.Family(id=str(uuid4()), name="Family (FB)")
        user = models.User(id=str(uuid4()), familyId=fam.id, email=email, displayName=data.get('name','FB User'), role="parent")
        d.add(fam); d.add(user); d.commit()
    return TokenRes(accessToken=create_jwt(user.id, user.role))
