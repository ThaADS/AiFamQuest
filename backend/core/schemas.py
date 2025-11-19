from pydantic import BaseModel, EmailStr
from typing import Optional, List, Dict, Any
from datetime import datetime, date

# === Authentication ===
class TokenRes(BaseModel): accessToken: str
class LoginReq(BaseModel): email: EmailStr; password: str; otp: Optional[str] = None
class RegisterReq(BaseModel): familyName: str; email: EmailStr; password: str; displayName: str
class UserOut(BaseModel): id: str; familyId: str; email: EmailStr; displayName: str; role: str; locale: str; theme: str

# === 2FA Schemas ===
class TwoFASetupRes(BaseModel):
    secret: str
    otpauth_url: str
    qr_code_url: str  # Data URL for QR code image

class TwoFAVerifySetupReq(BaseModel):
    secret: str
    code: str

class TwoFAVerifySetupRes(BaseModel):
    success: bool
    backup_codes: List[str]
    message: str

class TwoFAVerifyReq(BaseModel):
    email: EmailStr
    password: str
    code: str

class TwoFADisableReq(BaseModel):
    password: str
    code: str  # TOTP code or backup code

class BackupCodesRes(BaseModel):
    backup_codes: List[str]
    message: str

# === Apple Sign-In Schemas ===
class AppleSignInReq(BaseModel):
    id_token: str
    authorization_code: Optional[str] = None
    user_info: Optional[Dict[str, Any]] = None  # Only provided on first sign-in

# === Tasks & Rewards ===
class TaskIn(BaseModel):
    title: str
    desc: Optional[str] = ""
    due: Optional[datetime] = None
    assignees: List[str] = []
    points: int = 10
    category: str = "other"
    frequency: str = "none"
    rrule: Optional[str] = None
    rotationStrategy: str = "manual"
    estDuration: int = 15
    priority: str = "med"
    photoRequired: bool = False
    parentApproval: bool = False
    claimable: bool = False

class TaskOut(BaseModel):
    id: str
    familyId: str
    title: str
    desc: str
    category: str
    due: Optional[datetime] = None
    frequency: str
    rrule: Optional[str] = None
    rotationStrategy: str
    rotationState: Dict[str, Any]
    assignees: List[str]
    claimable: bool
    claimedBy: Optional[str] = None
    claimedAt: Optional[datetime] = None
    status: str
    points: int
    photoRequired: bool
    parentApproval: bool
    proofPhotos: List[str]
    priority: str
    estDuration: int
    createdBy: str
    completedBy: Optional[str] = None
    completedAt: Optional[datetime] = None
    version: int
    createdAt: datetime
    updatedAt: datetime

    class Config:
        from_attributes = True

class TaskUpdate(BaseModel):
    title: Optional[str] = None
    desc: Optional[str] = None
    due: Optional[datetime] = None
    assignees: Optional[List[str]] = None
    points: Optional[int] = None
    category: Optional[str] = None
    frequency: Optional[str] = None
    rrule: Optional[str] = None
    rotationStrategy: Optional[str] = None
    estDuration: Optional[int] = None
    priority: Optional[str] = None
    photoRequired: Optional[bool] = None
    parentApproval: Optional[bool] = None
    claimable: Optional[bool] = None
    status: Optional[str] = None

class FairnessReportOut(BaseModel):
    """Fairness distribution report for parent dashboard"""
    fairness_scores: Dict[str, float]  # user_id -> workload percentage
    week_start: date
    week_end: date
    recommendations: List[Dict[str, Any]]  # Suggestions for balancing workload
    over_capacity: List[str]  # User IDs at/over capacity
    under_capacity: List[str]  # User IDs under 50% capacity

class TaskOccurrenceOut(BaseModel):
    """Single occurrence of recurring task"""
    occurrence_date: str
    is_generated: bool
    is_skipped: bool
    instance_id: Optional[str]
    status: str
    assignee_id: Optional[str]

class RewardIn(BaseModel): name: str; cost: int
class RewardOut(BaseModel): id: str; name: str; cost: int

# === Notifications ===
class DeviceTokenIn(BaseModel): platform: str; token: str
class WebPushSubIn(BaseModel): endpoint: str; p256dh: str; auth: str

# === AI Planning ===
class PlanReq(BaseModel): weekContext: Dict[str, Any]

# Event schemas
class EventBase(BaseModel):
    title: str
    description: str = ""
    start: datetime
    end: Optional[datetime] = None
    allDay: bool = False
    attendees: List[str] = []
    color: Optional[str] = None
    rrule: Optional[str] = None
    category: str = "other"

class EventCreate(EventBase):
    pass

class EventUpdate(EventBase):
    pass

class EventOut(EventBase):
    id: str
    familyId: str
    createdBy: str
    createdAt: datetime
    updatedAt: datetime

    class Config:
        from_attributes = True

# === Kiosk Mode ===
class KioskTaskOut(BaseModel):
    """Task information for kiosk display"""
    id: str
    title: str
    due_time: Optional[str] = None  # HH:MM format
    points: int
    status: str
    photo_required: bool

class KioskEventOut(BaseModel):
    """Event information for kiosk display"""
    id: str
    title: str
    start_time: str  # HH:MM format
    end_time: Optional[str] = None  # HH:MM format

class KioskMemberOut(BaseModel):
    """Family member with tasks and events for kiosk"""
    user_id: str
    name: str
    avatar_url: Optional[str] = None
    capacity_pct: float
    tasks: List[KioskTaskOut]
    events: List[KioskEventOut]

class KioskTodayOut(BaseModel):
    """Today's overview for kiosk mode"""
    date: str  # YYYY-MM-DD format
    members: List[KioskMemberOut]

class KioskDayOut(BaseModel):
    """Single day summary for week view"""
    date: str  # YYYY-MM-DD format
    day_name: str
    members: List[KioskMemberOut]

class KioskWeekOut(BaseModel):
    """Week overview for kiosk mode"""
    start_date: str  # YYYY-MM-DD format
    end_date: str  # YYYY-MM-DD format
    days: List[KioskDayOut]

class KioskPinVerifyReq(BaseModel):
    """PIN verification request for kiosk exit"""
    pin: str

class KioskPinVerifyRes(BaseModel):
    """PIN verification response"""
    valid: bool
    error: Optional[str] = None
