from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from starlette.staticfiles import StaticFiles
from routers import auth, users, tasks, calendar, rewards, ai, gamification, notify, admin, media, ws, notifications, fairness, helpers, translations, premium, kiosk
app = FastAPI(title="FamQuest API v10", version="10.0.0")
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_credentials=True, allow_methods=["*"], allow_headers=["*"])
app.include_router(auth.router, prefix="/auth", tags=["auth"])
app.include_router(users.router, prefix="/users", tags=["users"])
app.include_router(tasks.router, prefix="/tasks", tags=["tasks"])
app.include_router(calendar.router, prefix="/calendar", tags=["calendar"])
app.include_router(rewards.router, prefix="/rewards", tags=["rewards"])
app.include_router(ai.router, prefix="/ai", tags=["ai"])
app.include_router(gamification.router, prefix="/gamification", tags=["gamification"])
app.include_router(notify.router, prefix="/notify", tags=["notifications"])
app.include_router(notifications.router, prefix="/notifications", tags=["notifications"])
app.include_router(fairness.router, prefix="/fairness", tags=["fairness"])
app.include_router(helpers.router, prefix="/helpers", tags=["helpers"])
app.include_router(admin.router, prefix="/admin", tags=["admin"])
app.include_router(media.router, prefix="/media", tags=["media"])
app.include_router(translations.router, tags=["translations"])
app.include_router(premium.router, tags=["premium"])
app.include_router(kiosk.router, prefix="/kiosk", tags=["kiosk"])
app.include_router(ws.router, tags=["realtime"])
app.mount("/uploads", StaticFiles(directory="uploads"), name="uploads")
@app.get("/health")
def health(): return {"status":"ok"}
