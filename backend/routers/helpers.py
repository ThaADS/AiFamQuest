"""
Helper Invite System Router

Endpoints for:
- Creating helper invites with 6-digit PIN
- Verifying invite codes
- Accepting invites and creating helper accounts
- Managing active helpers
- Deactivating helpers

Helpers are temporary users (babysitters, grandparents, etc.) with limited permissions.
"""

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session
from core.db import SessionLocal
from core.deps import get_current_user, require_role
from core.models import User, Family
from pydantic import BaseModel, EmailStr, Field
from typing import List, Optional, Dict
from datetime import datetime, timedelta
import random
import string

router = APIRouter()


def db():
    """Database session dependency"""
    d = SessionLocal()
    try:
        yield d
    finally:
        d.close()


# We'll define HelperInvite model inline for now (will be added to models.py)
class HelperInvite(BaseModel):
    """Helper invite data (stored in database)"""
    id: str
    familyId: str
    createdById: str
    code: str
    name: str
    email: str
    startDate: datetime
    endDate: datetime
    permissions: Dict
    expiresAt: datetime
    used: bool
    usedAt: Optional[datetime] = None
    usedById: Optional[str] = None
    createdAt: datetime


class HelperInviteCreate(BaseModel):
    """Create helper invite payload"""
    name: str = Field(..., min_length=1, max_length=100, description="Helper's name")
    email: EmailStr = Field(..., description="Helper's email")
    start_date: datetime = Field(..., description="Start date for helper access")
    end_date: datetime = Field(..., description="End date for helper access")
    permissions: Dict = Field(
        default={"can_view": True, "can_complete": True, "can_upload_photos": False},
        description="Helper permissions"
    )

    class Config:
        json_schema_extra = {
            "example": {
                "name": "Sarah Wilson",
                "email": "sarah@example.com",
                "start_date": "2025-11-15T00:00:00Z",
                "end_date": "2025-11-22T00:00:00Z",
                "permissions": {
                    "can_view": True,
                    "can_complete": True,
                    "can_upload_photos": False
                }
            }
        }


class HelperInviteOut(BaseModel):
    """Helper invite response"""
    code: str
    expires_at: str
    invite_id: str
    name: str
    start_date: str
    end_date: str


class HelperOut(BaseModel):
    """Helper user response"""
    id: str
    display_name: str
    email: str
    role: str
    permissions: Dict
    helper_start_date: Optional[str]
    helper_end_date: Optional[str]
    created_at: str


# In-memory storage for helper invites (until migration is created)
# In production, this would be a database table
_helper_invites_storage: Dict[str, Dict] = {}


@router.post("/invite", response_model=HelperInviteOut)
async def create_helper_invite(
    invite: HelperInviteCreate,
    d: Session = Depends(db),
    payload=Depends(require_role(["parent"]))
):
    """
    Create helper invite (parents only).

    Generates a 6-digit PIN code that expires in 7 days.

    Returns:
        Invite code and expiration details
    """
    user = d.query(User).filter_by(id=payload["sub"]).first()
    if not user:
        raise HTTPException(404, "User not found")

    # Validate dates
    if invite.end_date <= invite.start_date:
        raise HTTPException(400, "End date must be after start date")

    if invite.start_date < datetime.utcnow():
        raise HTTPException(400, "Start date cannot be in the past")

    # Generate 6-digit code
    code = ''.join(random.choices(string.digits, k=6))

    # Ensure code is unique
    while code in _helper_invites_storage:
        code = ''.join(random.choices(string.digits, k=6))

    # Create invite
    invite_id = str(__import__('uuid').uuid4())
    expires_at = datetime.utcnow() + timedelta(days=7)

    invite_data = {
        "id": invite_id,
        "family_id": user.familyId,
        "created_by_id": user.id,
        "code": code,
        "name": invite.name,
        "email": invite.email,
        "start_date": invite.start_date,
        "end_date": invite.end_date,
        "permissions": invite.permissions,
        "expires_at": expires_at,
        "used": False,
        "used_at": None,
        "used_by_id": None,
        "created_at": datetime.utcnow()
    }

    _helper_invites_storage[code] = invite_data

    return HelperInviteOut(
        code=code,
        expires_at=expires_at.isoformat(),
        invite_id=invite_id,
        name=invite.name,
        start_date=invite.start_date.isoformat(),
        end_date=invite.end_date.isoformat()
    )


@router.post("/verify")
async def verify_helper_code(
    code: str = Query(..., min_length=6, max_length=6, description="6-digit invite code"),
    d: Session = Depends(db)
):
    """
    Verify helper invite code.

    Returns invite details if valid.

    Checks:
    - Code exists
    - Not already used
    - Not expired
    """
    # Get invite from storage
    invite_data = _helper_invites_storage.get(code)

    if not invite_data:
        raise HTTPException(404, "Invalid or expired code")

    # Check if already used
    if invite_data["used"]:
        raise HTTPException(400, "Code has already been used")

    # Check if expired
    if invite_data["expires_at"] < datetime.utcnow():
        raise HTTPException(400, "Code has expired")

    # Get family info
    family = d.query(Family).filter(Family.id == invite_data["family_id"]).first()
    parent = d.query(User).filter(User.id == invite_data["created_by_id"]).first()

    if not family or not parent:
        raise HTTPException(404, "Family or parent not found")

    return {
        "valid": True,
        "family_name": family.name,
        "parent_name": parent.displayName,
        "helper_name": invite_data["name"],
        "start_date": invite_data["start_date"].isoformat(),
        "end_date": invite_data["end_date"].isoformat(),
        "permissions": invite_data["permissions"]
    }


@router.post("/accept")
async def accept_helper_invite(
    code: str = Query(..., min_length=6, max_length=6, description="6-digit invite code"),
    password: Optional[str] = Query(None, description="Optional password for helper account"),
    d: Session = Depends(db)
):
    """
    Accept helper invite and create helper account.

    Creates a new user with role='helper' and limited permissions.

    Returns:
        Auth tokens for the new helper account
    """
    # Get invite from storage
    invite_data = _helper_invites_storage.get(code)

    if not invite_data:
        raise HTTPException(404, "Invalid or expired code")

    # Check if already used
    if invite_data["used"]:
        raise HTTPException(400, "Code has already been used")

    # Check if expired
    if invite_data["expires_at"] < datetime.utcnow():
        raise HTTPException(400, "Code has expired")

    # Check if email already exists
    existing_user = d.query(User).filter(User.email == invite_data["email"]).first()
    if existing_user:
        raise HTTPException(400, "Email already registered")

    # Create helper user
    helper_id = str(__import__('uuid').uuid4())

    # Hash password if provided
    password_hash = None
    if password:
        from passlib.context import CryptContext
        pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
        password_hash = pwd_context.hash(password)

    helper = User(
        id=helper_id,
        familyId=invite_data["family_id"],
        email=invite_data["email"],
        displayName=invite_data["name"],
        role='helper',
        passwordHash=password_hash,
        permissions=invite_data["permissions"],
        emailVerified=True,  # Auto-verify helpers
        createdAt=datetime.utcnow(),
        updatedAt=datetime.utcnow()
    )

    # Note: helper_start_date and helper_end_date will be added in migration
    # For now, we'll store them in permissions dict
    helper.permissions["helper_start_date"] = invite_data["start_date"].isoformat()
    helper.permissions["helper_end_date"] = invite_data["end_date"].isoformat()

    d.add(helper)

    # Mark invite as used
    invite_data["used"] = True
    invite_data["used_at"] = datetime.utcnow()
    invite_data["used_by_id"] = helper_id

    d.commit()
    d.refresh(helper)

    # Generate auth tokens
    from core.security import create_access_token, create_refresh_token

    access_token = create_access_token({"sub": helper_id})
    refresh_token = create_refresh_token({"sub": helper_id})

    return {
        "access_token": access_token,
        "refresh_token": refresh_token,
        "token_type": "bearer",
        "user": {
            "id": helper.id,
            "email": helper.email,
            "display_name": helper.displayName,
            "role": helper.role,
            "family_id": helper.familyId,
            "permissions": helper.permissions
        }
    }


@router.get("", response_model=List[HelperOut])
async def list_helpers(
    d: Session = Depends(db),
    payload=Depends(require_role(["parent"]))
):
    """
    List active helpers for family (parents only).

    Returns:
        List of helper users with active access
    """
    user = d.query(User).filter_by(id=payload["sub"]).first()
    if not user:
        raise HTTPException(404, "User not found")

    # Get all helper users for this family
    helpers = d.query(User).filter(
        User.familyId == user.familyId,
        User.role == 'helper'
    ).all()

    # Filter by end date (if stored in permissions)
    active_helpers = []
    for helper in helpers:
        helper_end_date_str = helper.permissions.get("helper_end_date")
        if helper_end_date_str:
            helper_end_date = datetime.fromisoformat(helper_end_date_str.replace('Z', '+00:00'))
            if helper_end_date > datetime.utcnow():
                active_helpers.append(helper)
        else:
            # No end date, assume active
            active_helpers.append(helper)

    return [
        HelperOut(
            id=h.id,
            display_name=h.displayName,
            email=h.email,
            role=h.role,
            permissions=h.permissions,
            helper_start_date=h.permissions.get("helper_start_date"),
            helper_end_date=h.permissions.get("helper_end_date"),
            created_at=h.createdAt.isoformat()
        )
        for h in active_helpers
    ]


@router.delete("/{helper_id}")
async def deactivate_helper(
    helper_id: str,
    d: Session = Depends(db),
    payload=Depends(require_role(["parent"]))
):
    """
    Deactivate helper (parents only).

    Sets helper's end date to now (soft delete).

    Returns:
        Success confirmation
    """
    user = d.query(User).filter_by(id=payload["sub"]).first()
    if not user:
        raise HTTPException(404, "User not found")

    helper = d.query(User).filter(
        User.id == helper_id,
        User.familyId == user.familyId,
        User.role == 'helper'
    ).first()

    if not helper:
        raise HTTPException(404, "Helper not found")

    # Set end date to now
    helper.permissions["helper_end_date"] = datetime.utcnow().isoformat()
    d.commit()

    return {
        "success": True,
        "helper_id": helper_id,
        "message": f"Helper {helper.displayName} deactivated"
    }


@router.get("/invites")
async def list_invites(
    d: Session = Depends(db),
    payload=Depends(require_role(["parent"]))
):
    """
    List all helper invites for family (parents only).

    Shows both used and unused invites.

    Returns:
        List of invites with status
    """
    user = d.query(User).filter_by(id=payload["sub"]).first()
    if not user:
        raise HTTPException(404, "User not found")

    # Get all invites for this family
    family_invites = [
        invite for invite in _helper_invites_storage.values()
        if invite["family_id"] == user.familyId
    ]

    # Sort by creation date (newest first)
    family_invites.sort(key=lambda x: x["created_at"], reverse=True)

    return {
        "invites": [
            {
                "code": invite["code"],
                "name": invite["name"],
                "email": invite["email"],
                "start_date": invite["start_date"].isoformat(),
                "end_date": invite["end_date"].isoformat(),
                "expires_at": invite["expires_at"].isoformat(),
                "used": invite["used"],
                "used_at": invite["used_at"].isoformat() if invite["used_at"] else None,
                "created_at": invite["created_at"].isoformat()
            }
            for invite in family_invites
        ],
        "total_count": len(family_invites)
    }


@router.delete("/invites/{code}")
async def revoke_invite(
    code: str,
    d: Session = Depends(db),
    payload=Depends(require_role(["parent"]))
):
    """
    Revoke helper invite (parents only).

    Prevents unused invite from being accepted.

    Returns:
        Success confirmation
    """
    user = d.query(User).filter_by(id=payload["sub"]).first()
    if not user:
        raise HTTPException(404, "User not found")

    # Get invite from storage
    invite_data = _helper_invites_storage.get(code)

    if not invite_data:
        raise HTTPException(404, "Invite not found")

    # Verify family ownership
    if invite_data["family_id"] != user.familyId:
        raise HTTPException(403, "Access denied")

    # Check if already used
    if invite_data["used"]:
        raise HTTPException(400, "Cannot revoke used invite")

    # Remove from storage
    del _helper_invites_storage[code]

    return {
        "success": True,
        "code": code,
        "message": "Invite revoked"
    }
