# FamQuest Backend v9 — FULL SOURCE
## Start
```bash
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
export DATABASE_URL=sqlite:///./famquest.db
alembic upgrade head
uvicorn main:app --reload
```
Zet `.env` met OpenRouter, SSO (Google/MS/FB/Apple-ready), Push (FCM/WebPush/APNs), MEDIA_DIR, PUBLIC_BASE.
