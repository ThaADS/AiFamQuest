from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from starlette.staticfiles import StaticFiles
from routers import (
    auth, users, tasks, calendar, rewards, ai, gamification, notify, media, ws,
    notifications, fairness, helpers, translations, premium, kiosk, voice, study, gdpr
)

app = FastAPI(
    title="FamQuest API",
    version="11.0.0",
    description="Complete family task management platform with AI-powered features"
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"]
)

# Core routers
app.include_router(auth.router, prefix="/auth", tags=["auth"])
app.include_router(users.router, prefix="/users", tags=["users"])
app.include_router(tasks.router, prefix="/tasks", tags=["tasks"])
app.include_router(calendar.router, prefix="/calendar", tags=["calendar"])
app.include_router(rewards.router, prefix="/rewards", tags=["rewards"])

# AI-powered features
app.include_router(ai.router, prefix="/ai", tags=["ai"])
app.include_router(voice.router, prefix="/voice", tags=["voice"])
app.include_router(study.router, prefix="/study", tags=["study"])

# Gamification
app.include_router(gamification.router, prefix="/gamification", tags=["gamification"])
app.include_router(fairness.router, prefix="/fairness", tags=["fairness"])

# Notifications
app.include_router(notify.router, prefix="/notify", tags=["notifications"])
app.include_router(notifications.router, prefix="/notifications", tags=["notifications"])

# Helper system
app.include_router(helpers.router, prefix="/helpers", tags=["helpers"])

# Media & storage
app.include_router(media.router, prefix="/media", tags=["media"])

# Premium & monetization
app.include_router(premium.router, tags=["premium"])

# GDPR compliance
app.include_router(gdpr.router, prefix="/gdpr", tags=["gdpr"])

# Internationalization
app.include_router(translations.router, tags=["translations"])

# Kiosk mode
app.include_router(kiosk.router, prefix="/kiosk", tags=["kiosk"])

# Real-time
app.include_router(ws.router, tags=["realtime"])
app.mount("/uploads", StaticFiles(directory="uploads"), name="uploads")
@app.get("/health")
def health(): return {"status":"ok"}
