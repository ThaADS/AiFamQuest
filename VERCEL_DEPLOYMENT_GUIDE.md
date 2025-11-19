# FamQuest Vercel Deployment Guide

Complete production deployment guide for FamQuest on Vercel infrastructure.

**Version:** 1.0
**Last Updated:** 2025-11-19
**Status:** Production-Ready Configuration

---

## Table of Contents

1. [Pre-Deployment Preparation](#pre-deployment-preparation)
2. [Environment Configuration](#environment-configuration)
3. [Build Configuration](#build-configuration)
4. [Database & Storage Setup](#database--storage-setup)
5. [Vercel Project Setup](#vercel-project-setup)
6. [Deployment Process](#deployment-process)
7. [Post-Deployment Validation](#post-deployment-validation)
8. [Monitoring & Maintenance](#monitoring--maintenance)
9. [Troubleshooting](#troubleshooting)
10. [Rollback Procedures](#rollback-procedures)

---

## Pre-Deployment Preparation

### 1. Code Quality & Security Audit

#### Run Security Audit
```bash
bash scripts/security_audit.sh
```

**Action Items:**
- ✅ Fix all CRITICAL security issues
- ✅ Update vulnerable dependencies
- ✅ Remove hardcoded secrets
- ✅ Verify .env in .gitignore

#### Run Code Quality Audit
```bash
bash scripts/code_quality.sh
```

**Action Items:**
- ✅ Apply code formatting (black, isort, dart format)
- ✅ Fix flake8/analyzer warnings
- ✅ Resolve type checking errors
- ✅ Remove debug code

### 2. Performance Optimization

#### Backend Optimization
- ✅ Database indexes created (run migration)
- ✅ Connection pooling configured
- ✅ Redis caching enabled
- ✅ Query optimization reviewed

#### Frontend Optimization
- ✅ Flutter bundle size <30MB
- ✅ Code splitting implemented
- ✅ Images optimized with CachedNetworkImage
- ✅ Const constructors applied
- ✅ Service worker configured

### 3. Testing
```bash
# Backend tests
cd backend
pytest --cov=. --cov-report=term

# Flutter tests
cd flutter_app
flutter test
flutter analyze
```

**Requirements:**
- ✅ Backend test coverage >80%
- ✅ Flutter tests passing
- ✅ No critical analyzer warnings

---

## Environment Configuration

### Required Environment Variables

**Critical Variables** (set in Vercel Dashboard):

#### Database & Cache
```bash
DATABASE_URL=postgresql://user:pass@host:5432/famquest
REDIS_URL=redis://host:6379/0
```

#### Security
```bash
SECRET_KEY=your-secret-key-min-32-characters
ENVIRONMENT=production
```

#### AI Services
```bash
OPENROUTER_API_KEY=sk-or-v1-...
# OR
GEMINI_API_KEY=AIzaSy...
```

#### SSO Authentication
```bash
GOOGLE_CLIENT_ID=123456789.apps.googleusercontent.com
GOOGLE_CLIENT_SECRET=GOCSPX-...
MICROSOFT_CLIENT_ID=...
MICROSOFT_CLIENT_SECRET=...
FACEBOOK_APP_ID=...
FACEBOOK_APP_SECRET=...
APPLE_CLIENT_ID=...
APPLE_KEY_ID=...
APPLE_TEAM_ID=...
```

#### Push Notifications
```bash
FCM_SERVER_KEY=AAAAxxxxxxx
APNS_KEY_ID=...
APNS_TEAM_ID=...
```

#### Storage (S3-compatible)
```bash
S3_BUCKET=famquest-media
S3_ACCESS_KEY=AKIAXXXXXXXXXXXXXXXX
S3_SECRET_KEY=...
S3_REGION=eu-west-1
```

#### Email
```bash
SENDGRID_API_KEY=SG.xxxxxxxxxxxxxxxx
EMAIL_FROM=noreply@famquest.app
```

#### Monitoring
```bash
SENTRY_DSN=https://xxx@sentry.io/xxx
```

### Setting Environment Variables in Vercel

```bash
# Install Vercel CLI
npm install -g vercel

# Login
vercel login

# Add secrets (stored encrypted)
vercel env add DATABASE_URL
vercel env add SECRET_KEY
vercel env add OPENROUTER_API_KEY
# ... (repeat for all variables)

# Or bulk add from file
vercel env pull .env.production
```

**Important:**
- Set variables for: Production, Preview, Development
- Use Vercel Secrets for sensitive data (prefixed with @)
- Never commit .env files

---

## Build Configuration

### Backend Build (FastAPI)

**File:** `backend/vercel.json`
```json
{
  "version": 2,
  "builds": [
    {
      "src": "main.py",
      "use": "@vercel/python",
      "config": {
        "maxLambdaSize": "15mb",
        "runtime": "python3.11"
      }
    }
  ]
}
```

**File:** `backend/requirements-vercel.txt` (lightweight, no dev deps)

**Optimization:**
- ✅ Remove dev dependencies (pytest, black, mypy)
- ✅ Use binary packages (psycopg2-binary)
- ✅ Limit to production essentials
- ✅ Total size <15MB compressed

### Flutter Web Build

```bash
cd flutter_app

# Production build
flutter build web --release \
  --tree-shake-icons \
  --dart-define=FLUTTER_WEB_USE_SKIA=false \
  --web-renderer html

# Verify bundle size
du -sh build/web
# Target: <30MB

# Optimize assets
cd build/web
find . -type f \( -name "*.js" -o -name "*.css" \) -exec gzip -9 -k {} \;
```

**Build Checklist:**
- ✅ Bundle size <30MB
- ✅ Service worker configured (sw.js)
- ✅ PWA manifest.json present
- ✅ No debug code/prints
- ✅ Environment variables via --dart-define

### Root Vercel Configuration

**File:** `vercel.json` (root)
```json
{
  "version": 2,
  "regions": ["iad1"],
  "builds": [
    {
      "src": "backend/main.py",
      "use": "@vercel/python"
    },
    {
      "src": "flutter_app/web/**",
      "use": "@vercel/static"
    }
  ],
  "routes": [
    { "src": "/api/(.*)", "dest": "backend/main.py" },
    { "src": "/health", "dest": "backend/main.py" },
    { "src": "/(.*)", "dest": "flutter_app/web/$1" }
  ],
  "headers": [...],
  "functions": {
    "backend/main.py": {
      "memory": 1024,
      "maxDuration": 10
    }
  }
}
```

**Key Settings:**
- ✅ API routes mapped to /api/*
- ✅ Static files from flutter_app/web
- ✅ Security headers configured
- ✅ Cache-Control optimized
- ✅ CORS restricted to production domains

---

## Database & Storage Setup

### PostgreSQL Database

**Recommended Providers:**
- Supabase (free tier: 500MB, 2 projects)
- Neon (serverless, autoscaling)
- Railway (dev-friendly)
- Vercel Postgres

**Setup Steps:**

1. **Create Database**
```bash
# Example: Supabase
supabase projects create famquest --org-id your-org-id

# Get connection string
supabase db remote --db-url
```

2. **Run Migrations**
```bash
cd backend
export DATABASE_URL="postgresql://..."
alembic upgrade head
```

3. **Add Performance Indexes**
```bash
# Create migration
alembic revision -m "add_performance_indexes"

# Add indexes (see PERFORMANCE_OPTIMIZATION_GUIDE.md)
# Run migration
alembic upgrade head
```

4. **Configure Connection Pooling**
- Enable pgBouncer (if using Supabase)
- Set pool_size=10, max_overflow=20
- Enable pool_pre_ping

### Redis Cache

**Recommended Providers:**
- Upstash (serverless, free tier: 10K commands/day)
- Redis Labs (cloud-managed)
- Railway Redis

**Setup:**
```bash
# Example: Upstash
# Create database → Copy REDIS_URL
# Add to Vercel environment variables
```

**Configuration:**
- maxmemory-policy: allkeys-lru
- maxmemory: 256mb (minimum)
- persistence: AOF

### S3 Storage (Media)

**Providers:**
- AWS S3
- Cloudflare R2 (no egress fees)
- DigitalOcean Spaces
- Supabase Storage

**Setup:**
```bash
# Create bucket
aws s3 mb s3://famquest-media --region eu-west-1

# Set CORS policy
aws s3api put-bucket-cors --bucket famquest-media --cors-configuration file://cors.json

# Enable versioning
aws s3api put-bucket-versioning --bucket famquest-media --versioning-configuration Status=Enabled
```

---

## Vercel Project Setup

### 1. Create Vercel Project

```bash
# From project root
vercel

# Follow prompts:
# - Setup and deploy? Yes
# - Which scope? [your-team]
# - Link to existing project? No
# - Project name? famquest
# - Directory? ./
# - Override settings? No

# This creates .vercel/ directory
```

### 2. Configure Custom Domain

**In Vercel Dashboard:**
1. Go to Project → Settings → Domains
2. Add domain: `famquest.app`
3. Configure DNS:
   - A record: `@` → `76.76.21.21` (Vercel IP)
   - CNAME: `www` → `cname.vercel-dns.com`
4. Wait for SSL certificate (automatic)

**Verify:**
```bash
dig famquest.app
curl https://famquest.app/health
```

### 3. Configure Security Headers

**Already in vercel.json:**
- X-Content-Type-Options: nosniff
- X-Frame-Options: DENY
- X-XSS-Protection: 1; mode=block
- Referrer-Policy: strict-origin-when-cross-origin

**Test:**
```bash
curl -I https://famquest.app | grep "X-"
```

### 4. Update CORS for Production

**File:** `backend/main.py`
```python
app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "https://famquest.app",
        "https://www.famquest.app",
        "https://famquest.vercel.app",  # Preview deployments
    ],
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "DELETE", "PATCH"],
    allow_headers=["*"]
)
```

**Commit and deploy:**
```bash
git add backend/main.py
git commit -m "chore: update CORS for production"
git push origin main
```

---

## Deployment Process

### Initial Deployment

```bash
# 1. Ensure all changes committed
git status
git add .
git commit -m "chore: production deployment setup"

# 2. Deploy to production
vercel --prod

# Output:
# Deploying famquest to production
# https://famquest.vercel.app
```

### Continuous Deployment

**Automatic Deployment:**
- Push to `main` branch → Production deployment
- Push to other branches → Preview deployment
- Pull requests → Preview deployment with unique URL

**Configure in Vercel Dashboard:**
1. Settings → Git
2. Production Branch: `main`
3. Build Command: (auto-detected)
4. Output Directory: (auto-detected)

### Manual Deployment

```bash
# Deploy specific commit
git checkout <commit-hash>
vercel --prod

# Deploy with alias
vercel --prod --alias famquest-v2.vercel.app
```

---

## Post-Deployment Validation

### 1. Smoke Tests

```bash
# Health check
curl https://api.famquest.app/health
# Expected: {"status":"ok"}

# API test (without auth)
curl https://api.famquest.app/api/translations/list
# Expected: JSON list of languages

# Authentication test
curl -X POST https://api.famquest.app/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"test123"}'
# Expected: {"access_token":"..."}
```

### 2. Frontend Tests

**Browser Test:**
1. Visit https://famquest.app
2. Verify: Page loads without errors
3. Check console: No JavaScript errors
4. Test: Login flow works
5. Test: Create task (if authenticated)

**PWA Test:**
1. Chrome → Three dots → Install app
2. Verify: App installs as PWA
3. Test: Works offline (with cached data)

### 3. Integration Tests

**Critical User Flows:**
- ✅ User registration
- ✅ Login (email + SSO)
- ✅ Task creation
- ✅ Task completion with photo
- ✅ Points awarded
- ✅ Badge unlocked
- ✅ Calendar event creation
- ✅ Real-time sync (2 devices)

### 4. Performance Validation

```bash
# Lighthouse audit
npx lighthouse https://famquest.app \
  --output html \
  --output json \
  --output-path ./lighthouse-report

# Check metrics
cat lighthouse-report.json | jq '.categories.performance.score'
# Target: >0.90 (90/100)
```

**Key Metrics:**
- First Contentful Paint: <1.5s
- Time to Interactive: <3s
- Largest Contentful Paint: <2.5s
- Cumulative Layout Shift: <0.1
- Total Blocking Time: <200ms

### 5. Load Testing

```bash
# Install locust
pip install locust

# Run load test
cd backend/tests
locust -f locustfile.py --headless \
  -u 100 \
  -r 10 \
  -t 60s \
  --host https://api.famquest.app

# Monitor:
# - Requests/sec > 50
# - Response time p95 < 200ms
# - Error rate < 1%
```

---

## Monitoring & Maintenance

### 1. Sentry Setup (Error Tracking)

**Backend:**
```python
# backend/main.py
import sentry_sdk

sentry_sdk.init(
    dsn=os.getenv("SENTRY_DSN"),
    environment="production",
    traces_sample_rate=0.1,
)
```

**Frontend:**
```dart
// flutter_app/lib/main.dart
import 'package:sentry_flutter/sentry_flutter.dart';

await SentryFlutter.init(
  (options) {
    options.dsn = const String.fromEnvironment('SENTRY_DSN');
    options.environment = 'production';
  },
  appRunner: () => runApp(MyApp()),
);
```

### 2. Vercel Analytics

**Enable:**
1. Vercel Dashboard → Project → Analytics
2. Enable Web Analytics
3. View metrics: Traffic, Core Web Vitals, Top Pages

**Custom Events:**
```html
<!-- flutter_app/web/index.html -->
<script>
  window.va = window.va || function () {
    (window.vaq = window.vaq || []).push(arguments);
  };
</script>
<script defer src="/_vercel/insights/script.js"></script>
```

### 3. Uptime Monitoring

**Recommended:** UptimeRobot (free tier: 50 monitors, 5-min interval)

**Setup:**
1. Create account
2. Add monitor:
   - Type: HTTP(s)
   - URL: https://api.famquest.app/health
   - Interval: 5 minutes
3. Configure alerts: Email/SMS/Slack

### 4. Database Monitoring

**Metrics to Track:**
- Connection pool usage
- Query performance (p95, p99)
- Slow query log (>100ms)
- Table sizes
- Index hit rate

**Tools:**
- Supabase Dashboard (built-in)
- pgAdmin (manual queries)
- pg_stat_statements (PostgreSQL extension)

### 5. Cost Monitoring

**Vercel Usage:**
- Function invocations
- Bandwidth (GB)
- Build minutes

**Database:**
- Storage size
- Backup size
- Connection hours

**Alerts:**
- Set budget alerts (e.g., $50/month threshold)
- Monitor daily usage trends

---

## Troubleshooting

### Issue: Function Timeout (10s limit)

**Symptoms:**
- 504 Gateway Timeout errors
- Slow API responses

**Solutions:**
1. Optimize database queries (add indexes)
2. Add caching layer (Redis)
3. Use async processing for heavy tasks
4. Split into multiple functions

**Check logs:**
```bash
vercel logs --follow
```

### Issue: Database Connection Pool Exhausted

**Symptoms:**
- "FATAL: remaining connection slots are reserved"
- API errors: 500 Internal Server Error

**Solutions:**
1. Increase pool size in `backend/core/db_optimized.py`
2. Enable pgBouncer
3. Check for connection leaks (missing .close())
4. Reduce max_overflow

**Debug:**
```python
# Add to health endpoint
@app.get("/health")
def health():
    from core.db_optimized import get_pool_stats
    return {"status": "ok", "pool": get_pool_stats()}
```

### Issue: CORS Errors

**Symptoms:**
- Browser console: "CORS policy: No 'Access-Control-Allow-Origin'"
- API calls fail from frontend

**Solutions:**
1. Verify allow_origins in backend/main.py
2. Check vercel.json headers
3. Test with curl -v

**Debug:**
```bash
curl -v -H "Origin: https://famquest.app" https://api.famquest.app/api/tasks
# Check for Access-Control-Allow-Origin header
```

### Issue: Flutter App Blank Page

**Symptoms:**
- White screen on load
- No errors in Vercel logs

**Solutions:**
1. Check browser console for JavaScript errors
2. Verify base href in index.html
3. Check service worker registration
4. Test in incognito mode (clear cache)

**Debug:**
```javascript
// Browser console
console.log(navigator.serviceWorker.controller);
// Should show active service worker
```

### Issue: Cold Start Latency

**Symptoms:**
- First request >5s
- Subsequent requests fast

**Solutions:**
1. Warm up connections on startup
2. Use Vercel Edge Config for static data
3. Implement request coalescing
4. Use Keep-Alive headers

**Optimization:**
```python
# backend/main.py
@app.on_event("startup")
async def startup():
    # Pre-warm database connection
    from core.db_optimized import engine
    with engine.connect() as conn:
        conn.execute("SELECT 1")
```

---

## Rollback Procedures

### Immediate Rollback

```bash
# Rollback to previous deployment
vercel rollback

# Or rollback to specific deployment
vercel rollback <deployment-url>
```

### Manual Rollback

```bash
# 1. Find working commit
git log --oneline
# Example: abc1234 Working version before bug

# 2. Deploy specific commit
git checkout abc1234
vercel --prod

# 3. Verify deployment
curl https://api.famquest.app/health

# 4. Return to main branch
git checkout main
```

### Database Rollback

```bash
# Rollback last migration
alembic downgrade -1

# Rollback to specific version
alembic downgrade <revision_id>

# Restore from backup (if needed)
pg_restore -d $DATABASE_URL backup.dump
```

### Communication Template

```
Subject: FamQuest Deployment Rollback - [Date]

Team,

We've rolled back the latest deployment due to [issue].

Status:
- Rollback completed: [time]
- Current version: [commit hash]
- Affected users: [estimated number]
- Resolution ETA: [time]

Next steps:
1. [Action item 1]
2. [Action item 2]

Updates: [Slack channel / Email]
```

---

## Deployment Checklist (Quick Reference)

### Before Deployment
- [ ] All tests passing (backend + frontend)
- [ ] Security audit completed
- [ ] Code formatted (black, dart format)
- [ ] Environment variables configured
- [ ] Database migrations ready
- [ ] CORS updated for production
- [ ] API keys secured (no commits)

### During Deployment
- [ ] Commit all changes
- [ ] Run `vercel --prod`
- [ ] Monitor deployment logs
- [ ] Verify build success

### After Deployment
- [ ] Health check passes
- [ ] Smoke tests pass
- [ ] Load test (100 users)
- [ ] Lighthouse audit >90
- [ ] Sentry error rate <1%
- [ ] Monitor for 15 minutes

### Rollback Ready
- [ ] Previous deployment URL saved
- [ ] Database backup available
- [ ] Rollback command tested
- [ ] Team notified

---

## Success Metrics

**Performance:**
- API latency <200ms (p95)
- Flutter load time <2s
- 60fps UI animations
- Lighthouse score >90

**Reliability:**
- Uptime >99.9%
- Error rate <0.1%
- Zero downtime deployments

**Scale:**
- 1K concurrent users supported
- 10K tasks/day processing
- 50K API requests/day

---

## Support Contacts

**Vercel Support:** support@vercel.com
**Supabase Support:** support@supabase.com
**Sentry Support:** support@sentry.io

**Emergency Rollback:** `vercel rollback`

---

**Guide Version:** 1.0
**Last Updated:** 2025-11-19
**Next Review:** After first production deployment
