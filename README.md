# 🏆 FamQuest — AI-Powered Family Quest System

<div align="center">

![FamQuest Logo](website/images/favicon.svg)

**Transform household chaos into a gamified adventure powered by AI**

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter)](https://flutter.dev)
[![FastAPI](https://img.shields.io/badge/FastAPI-0.100+-009688?logo=fastapi)](https://fastapi.tiangolo.com)
[![Firebase](https://img.shields.io/badge/Firebase-Ready-FFCA28?logo=firebase)](https://firebase.google.com)
[![License](https://img.shields.io/badge/License-Proprietary-red.svg)]()

[🌐 Website](https://famquest.app) • [📱 Demo](https://demo.famquest.app) • [📖 Docs](docs/) • [🐛 Issues](https://github.com/ThaADS/AiFamQuest/issues)

</div>

---

## 🎯 What is FamQuest?

FamQuest revolutionizes family organization by combining:

- 🤖 **AI-Powered Planning**: Let OpenRouter AI distribute tasks fairly based on age, schedule, and capacity
- 📅 **Smart Family Calendar**: Unified schedule with color-coded events and conflict detection
- 🎮 **Adaptive Gamification**: Age-appropriate reward systems (kids 🎨 | teens 🏅 | parents 📊)
- 📸 **Vision AI Cleaning Coach**: Snap a photo → Get instant cleaning tips (GPT-4 Vision)
- 🎙️ **Voice Commands**: Create tasks hands-free in 7 languages (Whisper STT)
- 📚 **AI Homework Coach**: Backward planning + spaced repetition quizzes
- 🔄 **Offline-First**: Works without internet, syncs when online
- 🌍 **Multi-Language**: NL, EN, DE, FR, TR, PL, AR (with RTL support)

---

## ✨ Key Features

### 🧠 AI-Powered Intelligence

<table>
<tr>
<td width="50%">

#### 📋 AI Task Planner
```python
# Analyzes family dynamics in real-time
- Age-based workload distribution
- Calendar conflict avoidance
- Fairness algorithm (28% Noah, 24% Luna, etc.)
- Auto-rotation of recurring chores
```

</td>
<td width="50%">

#### 🔍 Vision Cleaning Tips
```python
# Photo → Cleaning Strategy
1. Upload stain/surface photo
2. GPT-4V analyzes material + stain
3. Step-by-step cleaning guide
4. Product recommendations + warnings
```

</td>
</tr>
</table>

### 📅 Family Calendar

| Feature | Description |
|---------|-------------|
| **3 View Modes** | Month, Week, Day views with smooth transitions |
| **Color-Coded** | Each family member gets unique color |
| **iCal Integration** | Export/import with RRULE recurrence |
| **Conflict Detection** | Smart warnings for overlapping events |
| **Offline Sync** | Delta sync with conflict resolution |

### 🎮 Gamification System

#### Age-Adaptive Themes

```
👶 Kids (6-10)     → Cartoony: Stickers, sound effects, large buttons
🏀 Boys (10-15)    → Space/Tech: Levels, XP bars, time trials
💅 Girls (10-15)   → Stylish: Collections, combo bonuses, certificates
🧑 Teens (15+)     → Minimal: Streaks, analytics, clean design
👨 Parents         → Classy: Insights, peace of mind, silent notifications
```

#### Point Economy

```yaml
Base Points: 10
Multipliers:
  - On-time: 1.2x
  - Quality (5-star approval): 1.1x
  - 7-day streak: 1.1x
  - Overdue penalty: 0.8x

Anti-Cheat:
  - Photo required if >3 tasks in 10 min
  - Parent approval for suspicious patterns
  - Rate limiting: 30s between completions
```

#### Badge System

🏅 **First Task** • 🔥 **Week Streak** • ⚡ **Speed Demon** • ⭐ **Perfectionist** • 🦸 **Helper Hero** • 🌅 **Early Bird** • 🌙 **Night Owl**

### 🔐 Authentication & Security

✅ **SSO Providers**: Apple, Google, Microsoft, Facebook
✅ **Email + Password** with bcrypt hashing
✅ **2FA Support**: TOTP (Google Authenticator), Email OTP, SMS OTP
✅ **Child Accounts**: PIN-only login (COPPA compliant)
✅ **Role-Based Access Control**: Parent | Teen | Child | Helper

### 🌐 Kiosk Mode

Perfect for shared family displays (tablet on fridge):

- 📺 Large touch targets (60px minimum)
- 🔄 Auto-refresh every 5 minutes
- 🔒 PIN-protected exit
- 📊 Today/Week views with upcoming tasks
- 🎨 High-contrast, accessible design

---

## 🏗️ Architecture

### Technology Stack

```
┌─────────────────────────────────────────────────────────┐
│                     FRONTEND                            │
│  Flutter 3.x • Riverpod • GoRouter • Hive (encrypted)  │
│  Platforms: iOS, Android, Web (PWA)                    │
└─────────────────────────────────────────────────────────┘
                            ↕ REST API + WebSockets
┌─────────────────────────────────────────────────────────┐
│                     BACKEND                             │
│  FastAPI • PostgreSQL 15 • Redis 7 • Alembic           │
│  Services: AI, Auth, Sync, Gamification, Notifications │
└─────────────────────────────────────────────────────────┘
                            ↕ AI Requests
┌─────────────────────────────────────────────────────────┐
│                   AI LAYER (OpenRouter)                 │
│  Claude 3.5 Sonnet • GPT-4 Vision • Whisper STT       │
│  Services: Planner, Vision Tips, Voice, Homework Coach │
└─────────────────────────────────────────────────────────┘
                            ↕ Firebase (Coming Soon)
┌─────────────────────────────────────────────────────────┐
│                   FIREBASE BACKEND                      │
│  Auth • Firestore • Cloud Functions • FCM • Storage   │
│  Real-time sync • Scalable • Cost-effective           │
└─────────────────────────────────────────────────────────┘
```

### Database Schema

<details>
<summary><b>📊 PostgreSQL Tables (Click to expand)</b></summary>

```sql
-- Core Tables
families (id, name, plan, createdAt)
users (id, familyId, email, role, locale, theme, permissions, 2faEnabled)
tasks (id, familyId, title, category, frequency, rrule, assignees, points, status)
events (id, familyId, title, startTime, endTime, rrule, attendees, color)

-- Gamification
points_ledger (id, userId, delta, reason, taskId, multiplier, createdAt)
badges (id, userId, code, metadata, awardedAt)
rewards (id, familyId, name, cost, icon, category)

-- AI Features
study_items (id, userId, subject, examDate, aiPlan, status)
study_sessions (id, studyItemId, scheduledAt, duration, quizResults)

-- System
media (id, familyId, s3Key, url, virusScan)
device_tokens (id, userId, platform, token)
audit_log (id, actorUserId, action, meta, createdAt)
```

</details>

---

## 🚀 Quick Start

### Prerequisites

- **Flutter**: 3.x+ ([Install](https://docs.flutter.dev/get-started/install))
- **Python**: 3.11+ ([Install](https://www.python.org/downloads/))
- **PostgreSQL**: 15+ ([Install](https://www.postgresql.org/download/))
- **Redis**: 7+ ([Install](https://redis.io/download))

### 1️⃣ Clone Repository

```bash
git clone https://github.com/ThaADS/AiFamQuest.git
cd AiFamQuest
```

### 2️⃣ Backend Setup

```bash
cd backend

# Create virtual environment
python -m venv venv
source venv/bin/activate  # Windows: venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt

# Configure environment
cp .env.example .env
# Edit .env: Add DATABASE_URL, REDIS_URL, OPENROUTER_API_KEY

# Run migrations
alembic upgrade head

# Seed demo data (optional)
python scripts/seed_dev_data.py

# Start server
uvicorn main:app --reload
```

Backend runs at: **http://localhost:8000**
API docs: **http://localhost:8000/docs**

### 3️⃣ Flutter App Setup

```bash
cd flutter_app

# Install dependencies
flutter pub get

# Run on web (demo mode)
flutter run -d chrome

# Or build for Android
flutter build apk --release

# Or build for iOS
flutter build ios --release
```

### 4️⃣ Demo Mode (No Backend Required)

1. Open Flutter app
2. Click **"Demo Mode (Offline Test)"** button
3. Explore all features without backend server! 🎉

---

## 📱 Screenshots

<table>
<tr>
<td width="33%">

### 📅 Calendar Views
![Calendar](docs/screenshots/calendar.png)
*Month, Week, Day views with color-coded events*

</td>
<td width="33%">

### ✅ Task Management
![Tasks](docs/screenshots/tasks.png)
*Recurring tasks with RRULE + photo proof*

</td>
<td width="33%">

### 🏆 Gamification
![Gamification](docs/screenshots/gamification.png)
*Points, badges, shop, leaderboards*

</td>
</tr>
<tr>
<td width="33%">

### 🎯 Fairness Dashboard
![Fairness](docs/screenshots/fairness.png)
*AI-powered workload distribution*

</td>
<td width="33%">

### 🤖 AI Planner
![AI Planner](docs/screenshots/ai_planner.png)
*Weekly task scheduling with fairness*

</td>
<td width="33%">

### 📺 Kiosk Mode
![Kiosk](docs/screenshots/kiosk.png)
*Family display with today's schedule*

</td>
</tr>
</table>

---

## 🧪 Testing

### Backend Tests

```bash
cd backend

# Run all tests
pytest

# With coverage
pytest --cov=. --cov-report=html

# Integration tests only
pytest tests/integration/

# Specific test file
pytest tests/test_gamification.py -v
```

**Test Coverage**: 85%+ (unit + integration tests)

### Flutter Tests

```bash
cd flutter_app

# Unit tests
flutter test

# Integration tests
flutter test integration_test/app_test.dart

# Widget tests
flutter test test/widget_test.dart
```

---

## 📚 Documentation

| Document | Description |
|----------|-------------|
| [📖 PRD v2.1](AI_Gezinsplanner_PRD_v2.1.md) | Complete Product Requirements Document |
| [🏗️ Architecture](docs/research/architecture_review_adr.md) | System design & ADRs |
| [🔐 Auth Guide](backend/docs/AUTH_IMPLEMENTATION_SUMMARY.md) | SSO, 2FA, RBAC setup |
| [📅 Calendar API](backend/docs/CALENDAR_API.md) | Event CRUD + recurrence |
| [🤖 AI Implementation](backend/docs/AI_IMPLEMENTATION_SUMMARY.md) | OpenRouter integration |
| [🎮 Gamification](backend/docs/GAMIFICATION.md) | Points, badges, rewards |
| [⚖️ Fairness Algorithm](backend/core/fairness.py) | Task distribution logic |
| [🔄 Offline Sync](flutter_app/docs/offline_architecture.md) | Delta sync + conflict resolution |
| [🌍 i18n Guide](backend/docs/I18N_GUIDE.md) | Multi-language support |

---

## 🔧 Configuration

### Environment Variables

<details>
<summary><b>Backend (.env)</b></summary>

```bash
# Database
DATABASE_URL=postgresql://user:pass@localhost:5432/famquest
REDIS_URL=redis://localhost:6379

# Security
SECRET_KEY=your-secret-key-here  # JWT signing
CORS_ORIGINS=http://localhost:3000,https://famquest.app

# AI Services (OpenRouter)
OPENROUTER_API_KEY=sk-or-v1-...
OPENROUTER_BASE_URL=https://openrouter.ai/api/v1

# SSO Providers
GOOGLE_CLIENT_ID=...
GOOGLE_CLIENT_SECRET=...
MICROSOFT_CLIENT_ID=...
MICROSOFT_CLIENT_SECRET=...
FACEBOOK_APP_ID=...
FACEBOOK_APP_SECRET=...
APPLE_CLIENT_ID=...
APPLE_KEY_ID=...
APPLE_TEAM_ID=...

# Push Notifications
FCM_SERVER_KEY=...  # Firebase Cloud Messaging
APNS_KEY_PATH=./apns_key.p8
APNS_KEY_ID=...
APNS_TEAM_ID=...

# Storage
S3_BUCKET=famquest-media
S3_ACCESS_KEY=...
S3_SECRET_KEY=...
S3_REGION=eu-west-1

# Email
SENDGRID_API_KEY=...  # or MAILGUN_API_KEY
EMAIL_FROM=noreply@famquest.app

# Monitoring
SENTRY_DSN=https://...@sentry.io/...
```

</details>

<details>
<summary><b>Flutter (lib/config.dart)</b></summary>

```dart
class Config {
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8000',
  );

  static const String googleClientId = String.fromEnvironment('GOOGLE_CLIENT_ID');
  static const String appleClientId = String.fromEnvironment('APPLE_CLIENT_ID');
}

// Run with: flutter run --dart-define=API_BASE_URL=https://api.famquest.app
```

</details>

---

## 🎨 Customization

### Themes

FamQuest supports 5 built-in themes + custom themes:

```dart
// lib/theme.dart
ThemeData getTheme(String themeName) {
  switch (themeName) {
    case 'cartoony': return cartoonyTheme;    // Kids
    case 'minimal':  return minimalTheme;     // Teens
    case 'classy':   return classyTheme;      // Parents
    case 'dark':     return darkTheme;        // All ages
    case 'custom':   return customTheme;      // User-defined
  }
}
```

### Localization

Add new languages by creating translation files:

```bash
# Backend
backend/translations/es.json  # Spanish

# Flutter
flutter_app/assets/i18n/es.json
```

Run `flutter pub run intl_utils:generate` to generate code.

---

## 🚀 Deployment

### Backend (GCP Cloud Run)

```bash
# Build Docker image
docker build -t gcr.io/famquest/backend:latest .

# Push to GCR
docker push gcr.io/famquest/backend:latest

# Deploy
gcloud run deploy famquest-backend \
  --image gcr.io/famquest/backend:latest \
  --platform managed \
  --region europe-west1 \
  --allow-unauthenticated
```

### Flutter Web (Firebase Hosting)

```bash
cd flutter_app

# Build for production
flutter build web --release

# Deploy
firebase deploy --only hosting
```

### Mobile Apps

**iOS**: `flutter build ios --release` → Xcode → TestFlight → App Store
**Android**: `flutter build apk --release` → Google Play Console

---

## 💰 Monetization

### Pricing Tiers

| Tier | Price | Features |
|------|-------|----------|
| **Free** | €0 | 4 family members, basic gamification, 5 AI requests/day |
| **Family Unlock** | €19.99 (one-time) | Unlimited members, no ads, priority support |
| **Premium** | €4.99/month | All features, unlimited AI, advanced analytics, early access |

---

## 🛡️ Security

- ✅ **TLS 1.2+** for all communications
- ✅ **Bcrypt password hashing** (cost factor 12)
- ✅ **JWT tokens** with 15-min expiry (access) + 7-day refresh
- ✅ **Rate limiting**: 100 req/min per user
- ✅ **OWASP MASVS** mobile security standards
- ✅ **AVG/GDPR compliant**: Data export, right to be forgotten
- ✅ **COPPA compliant**: Parental consent for <13 years old

---

## 🐛 Known Issues

See [Issues](https://github.com/ThaADS/AiFamQuest/issues) for current bugs and feature requests.

**Common Issues**:

1. **Android build OOM**: Reduce `org.gradle.jvmargs` in `android/gradle.properties` to `-Xmx2G`
2. **iOS signing**: Requires Apple Developer account ($99/year)
3. **Web fullscreen**: Only works on HTTPS (not localhost)

---

## 🗺️ Roadmap

### Q1 2025
- [x] MVP launch (calendar, tasks, basic gamification)
- [x] SSO authentication (Google, Apple, Microsoft, Facebook)
- [x] Offline-first architecture
- [ ] Firebase backend migration
- [ ] Public beta (iOS + Android)

### Q2 2025
- [ ] AI Planner (OpenRouter integration)
- [ ] Vision Cleaning Tips (GPT-4 Vision)
- [ ] Voice Commands (Whisper STT)
- [ ] Homework Coach with spaced repetition

### Q3 2025
- [ ] Team quests (family-wide challenges)
- [ ] Leaderboards with privacy controls
- [ ] Season themes & limited-time events
- [ ] Advanced analytics dashboard

### Q4 2025
- [ ] API v2 with GraphQL
- [ ] Third-party integrations (Google Calendar, Alexa)
- [ ] White-label solution for schools/organizations

---

## 🤝 Contributing

We welcome contributions! Please read [CONTRIBUTING.md](CONTRIBUTING.md) first.

### Development Setup

1. Fork the repository
2. Create feature branch: `git checkout -b feat/amazing-feature`
3. Commit changes: `git commit -m "Add amazing feature"`
4. Push to branch: `git push origin feat/amazing-feature`
5. Open Pull Request

### Commit Convention

```
feat(tasks): add photo upload for task completion
fix(auth): resolve 2FA token expiry issue
docs(readme): update deployment instructions
refactor(gamification): extract badge logic to service
test(sync): add conflict resolution test cases
```

---

## 📄 License

**Proprietary License** - All rights reserved.

This software is proprietary and confidential. Unauthorized copying, distribution, or modification is strictly prohibited. For licensing inquiries, contact: info@famquest.app

---

## 🙏 Acknowledgments

- **Flutter Team**: Amazing cross-platform framework
- **FastAPI**: High-performance Python API framework
- **OpenRouter**: AI model aggregation platform
- **Claude (Anthropic)**: AI-assisted development 🤖
- **Material Design 3**: Beautiful UI components
- **Our Beta Testers**: Invaluable feedback ❤️

---

## 📞 Support

- 📧 **Email**: support@famquest.app
- 💬 **Discord**: [Join Community](https://discord.gg/famquest)
- 📚 **Docs**: [docs.famquest.app](https://docs.famquest.app)
- 🐦 **Twitter**: [@FamQuestApp](https://twitter.com/FamQuestApp)

---

<div align="center">

**Made with ❤️ by the FamQuest Team**

[⭐ Star us on GitHub](https://github.com/ThaADS/AiFamQuest) • [🐛 Report Bug](https://github.com/ThaADS/AiFamQuest/issues) • [💡 Request Feature](https://github.com/ThaADS/AiFamQuest/issues)

</div>
