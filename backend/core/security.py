import os, time, jwt, pyotp, secrets, hashlib
from passlib.context import CryptContext
from typing import List, Dict, Optional
from datetime import datetime, timedelta
import io
import qrcode

JWT_SECRET = os.getenv("JWT_SECRET","dev_secret")
JWT_ISS = os.getenv("JWT_ISS","FamQuest")
JWT_AUD = os.getenv("JWT_AUD","famquest.app")
JWT_EXP_MIN = int(os.getenv("JWT_EXP_MIN","60"))
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

# Rate limiting storage (in-memory for MVP, use Redis for production)
_rate_limit_store: Dict[str, List[float]] = {}

def hash_password(p: str) -> str: return pwd_context.hash(p)
def verify_password(p: str, h: str) -> bool: return pwd_context.verify(p, h)
def create_jwt(sub: str, role: str) -> str:
    now = int(time.time())
    payload = {"iss": JWT_ISS, "aud": JWT_AUD, "iat": now, "exp": now + JWT_EXP_MIN*60, "sub": sub, "role": role}
    return jwt.encode(payload, JWT_SECRET, algorithm="HS256")

# ===== 2FA Functions =====
def verify_totp(secret: str, code: str) -> bool:
    """Verify TOTP code with ±1 time step tolerance (30s window)"""
    return pyotp.TOTP(secret).verify(code, valid_window=1)

def new_totp_secret() -> str:
    """Generate new TOTP secret"""
    return pyotp.random_base32()

def generate_totp_uri(secret: str, email: str, issuer: str = "FamQuest") -> str:
    """Generate otpauth:// URI for QR code"""
    return pyotp.totp.TOTP(secret).provisioning_uri(name=email, issuer_name=issuer)

def generate_qr_code(uri: str) -> bytes:
    """Generate QR code image as PNG bytes"""
    qr = qrcode.QRCode(version=1, box_size=10, border=5)
    qr.add_data(uri)
    qr.make(fit=True)
    img = qr.make_image(fill_color="black", back_color="white")
    buffer = io.BytesIO()
    img.save(buffer, format="PNG")
    return buffer.getvalue()

def generate_backup_codes(count: int = 10) -> List[str]:
    """Generate random backup codes (8 chars each)"""
    return [secrets.token_hex(4).upper() for _ in range(count)]

def hash_backup_code(code: str) -> str:
    """Hash backup code with SHA-256 (not bcrypt for speed)"""
    return hashlib.sha256(code.encode()).hexdigest()

def verify_backup_code(code: str, hashed: str) -> bool:
    """Verify backup code against hash"""
    return hash_backup_code(code) == hashed

# ===== Rate Limiting =====
def check_rate_limit(key: str, max_attempts: int = 5, window_minutes: int = 15) -> bool:
    """
    Check if rate limit exceeded for given key
    Returns True if allowed, False if rate limited
    """
    now = time.time()
    window_start = now - (window_minutes * 60)

    # Clean old attempts
    if key in _rate_limit_store:
        _rate_limit_store[key] = [t for t in _rate_limit_store[key] if t > window_start]
    else:
        _rate_limit_store[key] = []

    # Check limit
    if len(_rate_limit_store[key]) >= max_attempts:
        return False

    # Record attempt
    _rate_limit_store[key].append(now)
    return True

def reset_rate_limit(key: str):
    """Reset rate limit for key (used after successful auth)"""
    if key in _rate_limit_store:
        del _rate_limit_store[key]

# ===== Apple Sign-In JWT Verification =====
def verify_apple_jwt(id_token: str, client_id: str) -> Optional[Dict]:
    """
    Verify Apple Sign-In ID token
    Returns decoded payload if valid, None otherwise
    Note: This is simplified. Production should verify signature with Apple's public keys
    """
    try:
        # In production, fetch Apple public keys from:
        # https://appleid.apple.com/auth/keys
        # and verify signature properly

        # For MVP, we decode without signature verification (INSECURE FOR PRODUCTION)
        # TODO: Implement proper JWT signature verification with Apple public keys
        payload = jwt.decode(
            id_token,
            options={"verify_signature": False},  # TEMP: Must verify in production
            audience=client_id
        )

        # Validate required claims
        if payload.get("iss") != "https://appleid.apple.com":
            return None
        if payload.get("aud") != client_id:
            return None
        if payload.get("exp", 0) < time.time():
            return None

        return payload
    except Exception:
        return None
