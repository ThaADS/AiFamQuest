# FamQuest Gap Analysis: v9 Implementation vs PRD v2.1

**Analysis Date:** 2025-11-11
**PRD Version:** v2.1 (Ultra-Detail)
**Current Implementation:** v9
**Analyst:** Requirements Analyst Agent

---

## Executive Summary

**Critical Finding:** Current implementation represents ~15-20% of PRD v2.1 scope. The codebase is in early MVP stage with basic CRUD operations but missing most differentiating features.

**Risk Level:** 🔴 HIGH - Significant architecture decisions needed before scaling.

**Key Gaps:**
- 7+ missing database tables (Study, Events, Media with relationships)
- SSO partially implemented (Apple missing, no 2FA enforcement)
- AI services exist but are stubs (no real OpenRouter integration)
- Zero gamification logic (no streaks, badges logic, fairness engine)
- No offline-first architecture (Hive not implemented)
- Missing i18n infrastructure (7 locales required)
- No kiosk mode authentication/PIN system

---

## 1. Feature Inventory: Implementation Status

### 1.1 Core Modules

| Feature Area | PRD Requirement | Current Status | Gap Assessment |
|-------------|----------------|----------------|----------------|
| **Kalender** | Maand/Week/Dag views, ICS import/export, kiosk mode | 🔴 MISSING | Hardcoded event list, no Event model/CRUD |
| **Takenbord** | RRULE/cron recurrence, roulatie (fairness), claimable pool, TTL | 🟡 PARTIAL | Basic Task CRUD only, no recurrence/rotation |
| **Gamification** | Persona-specific (6-10/boys/girls/teens/parents), streaks, badges logic | 🔴 MISSING | Models exist, zero logic for earning/awarding |
| **AI Planner** | LLM-based task distribution with fairness engine | 🔴 STUB | Endpoint exists, no real OpenRouter integration |
| **Huiswerkcoach** | StudyItem + StudySessions, micro-quiz, spaced repetition | 🔴 MISSING | No StudyItem/StudySession models |
| **Vision Tips** | Photo analysis, surface/stain detection, cleaning steps | 🔴 STUB | Accepts upload, no vision model integration |
| **Voice/NLU** | ASR/NLU/TTS pipeline, 7 locale intents | 🔴 STUB | VoiceTaskScreen UI only, no backend |
| **Offline-First** | Hive local storage, delta-sync, conflict resolution | 🔴 MISSING | No Hive, no sync queue beyond basic cache |
| **Kiosk Mode** | PIN-exit, auto-refresh, `/kiosk/today` & `/week` | 🟡 PARTIAL | UI screen exists, no PIN/auth, no dedicated routes |

### 1.2 Authentication & Security

| Feature | PRD Requirement | Current Status | Gap |
|---------|----------------|----------------|-----|
| SSO Providers | Apple + Google + Microsoft + Facebook | 🟡 PARTIAL | Google/MS/FB done, Apple missing |
| 2FA | TOTP + Email/SMS OTP | 🟡 PARTIAL | TOTP setup exists, no enforcement flow |
| Child Accounts | Parent creates with PIN, limited permissions | 🔴 MISSING | No PIN system, no permission toggles in code |
| RBAC Matrix | parent/teen/child/helper with granular permissions | 🟡 PARTIAL | Roles exist, no permission enforcement |
| Email Verification | SSO emailVerified tracking | 🔴 MISSING | No emailVerified field in User model |

### 1.3 Localization & Accessibility

| Feature | PRD Requirement | Current Status | Gap |
|---------|----------------|----------------|-----|
| i18n | 7 locales (NL/EN/DE/FR/TR/PL/AR) with ICU MessageFormat | 🔴 MISSING | User.locale field exists, no translation files |
| RTL Support | AR locale right-to-left layout | 🔴 MISSING | No RTL directionality handling |
| Themes | cartoony/minimal/classy/dark per profile | 🟡 PARTIAL | User.theme field exists, no theme engine |
| Pictograms | Visual task indicators for kids (6-10) | 🔴 MISSING | No icon/pictogram system |

### 1.4 Monetization & Compliance

| Feature | PRD Requirement | Current Status | Gap |
|---------|----------------|----------------|-----|
| Free Tier | Kindveilige ads in parent views only | 🔴 MISSING | No ad integration |
| Family Unlock | One-time IAP, removes ads, unlimited members | 🔴 MISSING | No entitlement/purchase tracking |
| Premium Tier | Subscription with unlimited AI, all themes | 🔴 MISSING | No subscription management |
| AVG/COPPA | PII minimization, parental consent, data export | 🟡 PARTIAL | Basic audit log, no consent/export APIs |

---

## 2. Database Gap Analysis

### 2.1 Current Schema (9 Tables)

✅ Implemented:
- `families` (id, name)
- `users` (id, familyId, email, displayName, role, locale, theme, 2FA fields)
- `tasks` (id, familyId, title, desc, due, assignees CSV, status, points, version)
- `points_ledger` (id, userId, delta, reason)
- `badges` (id, userId, code, awardedAt)
- `rewards` (id, familyId, name, cost)
- `device_tokens` (id, userId, platform, token)
- `webpush_subs` (id, userId, endpoint, p256dh, auth)
- `audit_log` (id, actorUserId, familyId, action, meta)

### 2.2 Missing Tables (PRD Requirements)

❌ **CRITICAL MISSING:**

| Table | Purpose | PRD Reference | Blocks |
|-------|---------|---------------|--------|
| `events` | Calendar events (maand/week/dag) | Section 5.1 | Kalender module |
| `study_items` | Homework/toets topics, backward plan | Section 5.4 | Huiswerkcoach |
| `study_sessions` | 20-30m study blocks, micro-quiz results | Section 5.4 | Huiswerkcoach |
| `task_logs` | Task completion history + proofPhotos | Section 5.2 | Analytics, approval flow |
| `media` | Presigned URLs, AV-scan metadata | Section 9.2 | Vision, photo proofs |
| `user_streaks` | Daily streak tracking per user | Section 5.3 | Gamification loops |
| `family_quests` | Team challenges (phase 2) | Section 5.3 | Team gamification |
| `entitlements` | IAP/subscription tracking | Section 11 | Monetization |
| `sso_links` | User ↔ provider mappings | Section 9.1 | Multi-provider SSO |

### 2.3 Schema Issues in Existing Tables

🟡 **PARTIAL/NEEDS ENHANCEMENT:**

| Table | Current State | PRD Requirement | Fix Needed |
|-------|---------------|----------------|------------|
| `tasks` | assignees as CSV string | assignees: List[uuid] | Change to JSON array or junction table |
| `tasks` | No `frequency`, `claimable`, `photoRequired`, `parentApproval`, `priority`, `estDuration`, `createdBy` | Section 4.1 full Task schema | Add 7+ missing columns |
| `users` | No `avatar`, `permissions` JSON, `sso` object | Section 4.1 full User schema | Add avatar URL, permissions toggles |
| `users` | No `emailVerified` | Section 9.1 | Add boolean field |
| `badges` | Just `code` string | Badge definition with icon, name_i18n | Create `badge_definitions` table |
| `rewards` | No `icon`, `description_i18n` | Section 5.3 shop UI | Add display metadata |

---

## 3. API Gap Analysis

### 3.1 Implemented Endpoints

✅ **Auth Routes** (`/auth/*`):
- `POST /auth/register` - Family + parent creation
- `POST /auth/login` - Email/password with optional OTP
- `POST /auth/2fa/setup` - TOTP secret generation
- `GET /auth/sso/{google,microsoft,facebook}` - OAuth flows
- `GET /auth/sso/{provider}/callback` - Token exchange

✅ **User Routes** (`/users/*`):
- `GET /users/me` - Current user profile

✅ **Task Routes** (`/tasks/*`):
- `GET /tasks` - List family tasks
- `POST /tasks` - Create task
- `POST /tasks/{id}/complete` - Mark done (no photo/approval)

✅ **Calendar Routes** (`/calendar/*`):
- `GET /calendar` - Hardcoded event list

✅ **AI Routes** (`/ai/*`):
- `POST /ai/planner` - AI week plan (stub)
- `POST /ai/vision_upload` - Photo analysis (stub)

✅ **Other Routes**:
- `/rewards`, `/gamification`, `/notify`, `/media`, `/ws` (routers exist but minimal logic)

### 3.2 Missing Critical Endpoints

❌ **HIGH PRIORITY:**

| Endpoint | Purpose | PRD Ref | Complexity |
|----------|---------|---------|------------|
| `POST /auth/sso/apple` + callback | Apple Sign-In | 9.1 | M |
| `POST /auth/2fa/verify` | 2FA enforcement flow | 9.1 | S |
| `POST /auth/2fa/disable` | Disable 2FA with verification | 9.1 | S |
| `GET /auth/child/setup` | Parent creates child account with PIN | 9.1 | M |
| `POST /tasks/{id}/claim` | Claimable pool with TTL lock | 5.2 | M |
| `POST /tasks/{id}/approve` | Parent approval flow | 5.2 | S |
| `POST /tasks/{id}/photo` | Upload proof photo | 5.2 | M |
| `GET /tasks/rotation/preview` | Preview fairness roulatie | 5.2 | L |
| `GET /events` + `POST /events` | Full Event CRUD | 5.1 | M |
| `GET /calendar/ics` | ICS export | 5.1 | M |
| `POST /study/items` + sessions | Huiswerkcoach backend | 5.4 | L |
| `GET /gamification/streaks/{userId}` | Streak status + guard | 5.3 | M |
| `POST /gamification/badges/award` | Badge awarding logic | 5.3 | M |
| `GET /shop/rewards` + `POST /shop/redeem` | Shop with point deduction | 5.3 | M |
| `POST /ai/voice/intent` | NLU intent parsing | 5.6 | L |
| `POST /ai/voice/tts` | Text-to-speech response | 5.6 | M |
| `GET /data/export` | AVG data export (JSON/CSV) | 9.2 | M |
| `POST /data/delete` | Right to be forgotten | 9.2 | L |
| `GET /kiosk/today` + `/kiosk/week` | Dedicated kiosk endpoints | 5.1 | S |
| `POST /kiosk/pin/verify` | PIN-exit kiosk mode | 5.1 | S |

❌ **PHASE 2 (Could defer):**
- `/calendar/subscribe` (Google/Outlook)
- `/analytics/fairness` (deep dive)
- `/quests/*` (team challenges)

---

## 4. Frontend Gap Analysis

### 4.1 Implemented Screens (Flutter)

✅ Current:
- `LoginScreen` - Email/password login (SSO buttons placeholders?)
- `HomeScreen` - Task list + bottom nav (5 tabs)
- `VisionScreen` - Photo upload UI
- `ShopScreen` - Rewards shop UI (no backend connection)
- `AdminScreen` - Parent controls placeholder
- `KioskScreen` - Fullscreen view placeholder
- `VoiceTaskScreen` - Voice input UI

### 4.2 Missing Screens & Features

❌ **CRITICAL MISSING:**

| Screen/Feature | Purpose | PRD Ref | Complexity |
|----------------|---------|---------|------------|
| **Calendar Views** | Maand/Week/Dag with Event CRUD | 5.1 | XL |
| **Task Detail Modal** | Photo upload, approval request, completion flow | 5.2 | L |
| **Task Rotation Wizard** | Configure roulatie (round-robin/fairness/manual) | 5.2 | L |
| **Gamification HUD** | Persistent points/streak display on home | 5.3 | M |
| **Badge Award Animation** | Celebratory popup on badge earn | 5.3 | M |
| **Shop Redemption Flow** | Confirm purchase, deduct points | 5.3 | M |
| **Huiswerkcoach Screens** | Create StudyItem, view sessions, micro-quiz UI | 5.4 | XL |
| **Profile/Settings** | Theme picker, locale picker, 2FA toggle | UX | L |
| **Child Account Setup** | Parent flow to create child with PIN | 9.1 | M |
| **Kiosk PIN Entry** | Exit kiosk mode with parent PIN | 5.1 | S |
| **Offline Sync Status** | Visual indicator for sync queue/conflicts | 8 | M |
| **Push Notification Handler** | Handle FCM/APNs deep links | 10 | M |

❌ **UX POLISH:**
- Theme engine (4 themes per persona)
- Pictogram system for kids
- RTL layout for AR locale
- Persona-specific reward animations (stickers vs badges)

### 4.3 State Management Issues

🟡 Current: Basic `setState` in StatefulWidget
⚠️ PRD Requirement: Riverpod/Bloc for complex flows (offline queue, sync state)

**Gap:** No global state management → Blocks offline-first architecture.

---

## 5. Integration Gap Analysis

### 5.1 AI Services (OpenRouter)

| Service | PRD Requirement | Current Status | Gap |
|---------|----------------|----------------|-----|
| **Planner LLM** | Fairness engine, weekPlan JSON output | 🔴 STUB | Endpoint exists, no real API call |
| **Vision Tips** | Surface/stain detection, cleaning steps JSON | 🔴 STUB | Accepts photo, no vision model |
| **STT (Speech-to-Text)** | 7 locales for voice input | 🔴 MISSING | No ASR integration |
| **TTS (Text-to-Speech)** | Voice feedback in 7 locales | 🔴 MISSING | No TTS integration |
| **NLU Intent Parser** | Parse "Maak taak stofzuigen morgen 17:00" | 🔴 MISSING | No NLU logic |
| **Study Coach** | Backward planning, quiz generation | 🔴 MISSING | No StudyItem backend |

**Risk:** PRD assumes OpenRouter as broker for model multiplexing. Current code has placeholder functions with no API client initialization.

### 5.2 SSO Providers

| Provider | Current Status | Gap |
|----------|----------------|-----|
| Google | ✅ DONE | OAuth flow working |
| Microsoft | ✅ DONE | OAuth flow working |
| Facebook | ✅ DONE | OAuth flow working |
| Apple | 🔴 MISSING | No Sign in with Apple implementation |

**Blocker:** Apple Sign-In required for iOS App Store approval.

### 5.3 Push Notifications

| Platform | PRD Requirement | Current Status | Gap |
|----------|----------------|----------------|-----|
| APNs (iOS) | Token registration + deep links | 🔴 MISSING | device_tokens table exists, no sender logic |
| FCM (Android) | Token registration + deep links | 🔴 MISSING | device_tokens table exists, no sender logic |
| WebPush | Browser notifications with service worker | 🔴 MISSING | webpush_subs table exists, no Web Push logic |

**Gap:** Backend has storage for tokens, but no notification dispatch service (e.g., Firebase Admin SDK, py-vapid).

### 5.4 Offline-First & Sync

| Component | PRD Requirement | Current Status | Gap |
|-----------|----------------|----------------|-----|
| **Local Storage** | Hive encrypted boxes per entity | 🔴 MISSING | No Hive dependency |
| **Delta Sync** | Conflict resolution (done > open, LWW) | 🔴 MISSING | No sync service |
| **Optimistic UI** | Immediate feedback, queue + retry | 🟡 PARTIAL | Basic queue in ApiClient, no retry logic |
| **Sync Triggers** | app resume, network up, interval, pull-to-refresh | 🔴 MISSING | No background sync task |

**Blocker:** Offline-first is a PRD "Must Have" (MVP scope), but architecture is fully online-only.

---

## 6. Priority Matrix (MoSCoW)

### 6.1 MUST HAVE (MVP Blockers)

| Feature | Gap Size | Effort | Risk | Dependencies |
|---------|----------|--------|------|--------------|
| Event Model + Calendar CRUD | Large | L | High | None |
| Task recurrence (RRULE) | Medium | M | Medium | None |
| Task roulatie (fairness engine) | Large | L | High | AI Planner integration |
| Offline-first architecture (Hive + sync) | XL | XL | Critical | Refactor ApiClient |
| Gamification logic (streaks, badge awards) | Large | L | Medium | user_streaks table |
| Apple SSO | Small | M | High | App Store requirement |
| 2FA enforcement flow | Small | S | Low | None |
| i18n infrastructure (7 locales) | Medium | M | Medium | Translation files |
| Kiosk PIN system | Small | S | Low | None |
| AI Planner real integration | Medium | M | High | OpenRouter API key |
| Vision real integration | Medium | M | Medium | OpenRouter vision model |

### 6.2 SHOULD HAVE (MVP Nice-to-Have)

| Feature | Gap Size | Effort | Risk |
|---------|----------|--------|------|
| Huiswerkcoach (StudyItem + Sessions) | Large | XL | Medium |
| Voice NLU pipeline (STT/NLU/TTS) | Large | XL | Medium |
| Photo proof + approval flow | Medium | M | Low |
| Theme engine (4 themes) | Medium | M | Low |
| Push notifications (FCM/APNs) | Medium | M | Medium |
| Child account PIN setup | Small | M | Low |

### 6.3 COULD HAVE (Phase 2)

| Feature | Gap Size | Effort |
|---------|----------|--------|
| Team quests/challenges | Large | L |
| Deep analytics/fairness insights | Medium | M |
| ICS import/export | Small | M |
| Calendar subscribe (Google/Outlook) | Medium | L |
| Seasonal themes | Small | S |

### 6.4 WON'T HAVE (Out of Scope v2.1)

- Bank/zakgeld integrations
- School SIS integrations
- Public community features
- Smart home triggers

---

## 7. Dependency Mapping

### Critical Path for MVP Launch:

```
1. Database Schema Completion
   └─> Add Event, StudyItem, StudySession, TaskLog, Media, UserStreak, SSOLink, Entitlement tables
   └─> Migrate Task columns (frequency, claimable, photoRequired, etc.)
   └─> BLOCKS: All feature work

2. Offline-First Architecture
   └─> Integrate Hive for local storage
   └─> Build sync service with conflict resolution
   └─> Refactor ApiClient to use optimistic UI + queue
   └─> BLOCKS: Production readiness

3. Calendar Module
   └─> Event CRUD endpoints
   └─> Maand/Week/Dag Flutter views
   └─> Requires: Event table (from #1)
   └─> BLOCKS: Core use case ("gezinsplanner")

4. Task Recurrence + Rotation
   └─> RRULE parsing backend
   └─> Fairness engine (AI Planner integration)
   └─> Roulatie wizard UI
   └─> Requires: AI Planner (OpenRouter)
   └─> BLOCKS: Differentiation vs competitors

5. Gamification Logic
   └─> Streak tracking service
   └─> Badge awarding rules
   └─> Shop redemption with point ledger
   └─> Requires: user_streaks table, badge_definitions
   └─> BLOCKS: Kids motivation (core value prop)

6. i18n + Themes
   └─> Flutter intl setup (7 locales)
   └─> Theme engine with 4 variants
   └─> RTL support for AR
   └─> Requires: Translation files (can parallelize)
   └─> BLOCKS: Market expansion (TR/PL/AR)

7. Apple SSO + 2FA Enforcement
   └─> Apple Sign-In flow
   └─> 2FA verification endpoint
   └─> Requires: iOS developer account
   └─> BLOCKS: iOS App Store launch

8. AI Services Real Integration
   └─> OpenRouter API client
   └─> Planner LLM (weekPlan JSON)
   └─> Vision tips (surface/stain detection)
   └─> Requires: OpenRouter API key, model selection
   └─> BLOCKS: "AI-gestuurde" marketing claim
```

### Parallel Tracks (Can Develop Concurrently):

- **Track A:** Database + Backend APIs (Tasks 1, 3, 4, 5, 7)
- **Track B:** Frontend UI/UX (Theme engine, Calendar views, Task detail, Gamification HUD)
- **Track C:** AI Integration (OpenRouter client, Planner, Vision)
- **Track D:** i18n (Translation files, locale switching)

---

## 8. Effort Estimation (T-Shirt Sizes)

### By Feature Area:

| Area | Total Effort | Breakdown |
|------|--------------|-----------|
| **Database Schema** | XL (80h) | 8 tables + migrations + seed data |
| **Backend APIs** | XL (120h) | 20+ endpoints (Task rotation, Events, StudyItems, etc.) |
| **Offline-First Arch** | XL (100h) | Hive integration, sync service, conflict resolution |
| **Calendar Module** | L (60h) | 3 views + Event CRUD + ICS export |
| **Task Enhancements** | L (50h) | Recurrence, rotation, photo proofs, approval |
| **Gamification Logic** | L (50h) | Streaks, badges, shop redemption |
| **AI Integration** | L (60h) | OpenRouter client, Planner, Vision, STT/TTS/NLU |
| **Huiswerkcoach** | XL (80h) | StudyItem CRUD, sessions, quiz UI + backend |
| **i18n + Themes** | M (40h) | 7 locales, 4 theme variants, RTL |
| **Auth Enhancements** | M (30h) | Apple SSO, 2FA enforcement, child accounts |
| **Push Notifications** | M (30h) | FCM/APNs sender, WebPush, deep links |
| **Kiosk Mode** | S (15h) | PIN system, dedicated routes, auto-refresh |
| **UI/UX Polish** | L (50h) | Pictograms, animations, persona-specific UX |

**Total MVP Effort:** ~765 developer hours (~19 weeks for 1 FTE, ~9.5 weeks for 2 FTE)

---

## 9. Risk Analysis

### 🔴 CRITICAL RISKS:

| Risk | Impact | Probability | Mitigation |
|------|--------|------------|------------|
| **Offline-first refactor breaks existing code** | Showstopper | High | Incremental migration, feature flags, comprehensive tests |
| **OpenRouter API costs exceed budget** | Revenue negative | Medium | Set quotas, cache aggressively, model fallbacks |
| **AVG/COPPA compliance gaps** | Legal liability | Medium | Legal review, PII audit, consent flows |
| **Task rotation fairness algorithm bias** | User churn | High | A/B testing, parent override always available |
| **Database schema changes break migrations** | Data loss | Medium | Backup strategy, rollback plan, staging env |

### 🟡 HIGH RISKS:

| Risk | Impact | Mitigation |
|------|--------|------------|
| Apple SSO rejection (iOS review) | Store launch delay | Start Apple Developer account setup now |
| Hive encryption key management | User lockout | Cloud backup option, recovery flow |
| Translation quality (7 locales) | Bad UX in non-NL | Native speaker review, ICU MessageFormat |
| Gamification anti-cheat insufficient | Economy inflation | Parent approval heuristics, rate limits |
| WebSocket scaling for real-time sync | Performance | Redis pub/sub, horizontal scaling |

---

## 10. Recommendations

### Immediate Actions (Week 1-2):

1. **Architecture Decision Records (ADRs):**
   - Offline-first strategy (Hive vs SQLite vs hybrid)
   - State management (Riverpod vs Bloc vs GetX)
   - AI API client (direct OpenRouter vs abstraction layer)

2. **Database Schema Sprint:**
   - Design complete schema with all 16+ tables
   - Write Alembic migrations with rollback tests
   - Seed data for development/staging

3. **OpenRouter Integration Proof-of-Concept:**
   - Test Planner LLM with real family data
   - Validate Vision model accuracy with cleaning photos
   - Measure latency and cost per request

### Phase 1: MVP Foundation (Week 3-8):

**Priority 1 (Critical Path):**
- Offline-first architecture with Hive
- Event model + Calendar CRUD
- Task recurrence (RRULE) backend
- Gamification logic (streaks, badges)
- Apple SSO + 2FA enforcement

**Priority 2 (Core Features):**
- AI Planner real integration
- Vision tips real integration
- i18n infrastructure (NL/EN/DE/FR)
- Theme engine (minimal + dark themes first)
- Push notifications (FCM/APNs basic)

**Priority 3 (MVP Nice-to-Have):**
- Photo proof + approval flow
- Kiosk PIN system
- Shop redemption UI

**DEFER TO PHASE 2:**
- Huiswerkcoach (complex, can launch without)
- Voice NLU pipeline (complex, can launch without)
- Team quests
- Deep analytics

### Phase 2: Market Expansion (Week 9-16):

- Huiswerkcoach full implementation
- Voice NLU (7 locales)
- Remaining i18n locales (TR/PL/AR + RTL)
- Advanced theme variants (cartoony, classy)
- Team quests/challenges
- Fairness analytics dashboard

### Phase 3: Monetization & Scale (Week 17+):

- Family Unlock IAP
- Premium subscription
- Kindveilige ads integration
- ICS import/calendar subscribe
- Performance optimization
- Beta testing with 20-50 families

---

## 11. Prioritized Backlog

### Sprint 1-2: Architecture & Database (Week 1-2)

| Task | Effort | Priority | Owner |
|------|--------|----------|-------|
| ADR: Offline-first strategy | S | Must | Tech Lead |
| ADR: State management (Riverpod) | S | Must | Tech Lead |
| Design 16-table schema | M | Must | Backend Dev |
| Write Alembic migrations | M | Must | Backend Dev |
| OpenRouter POC (Planner + Vision) | M | Must | AI/Backend Dev |

### Sprint 3-4: Offline & Events (Week 3-4)

| Task | Effort | Priority | Owner |
|------|--------|----------|-------|
| Integrate Hive + encrypted boxes | L | Must | Flutter Dev |
| Build sync service (delta + conflicts) | L | Must | Flutter Dev |
| Event model + CRUD endpoints | M | Must | Backend Dev |
| Calendar Maand view (Flutter) | M | Must | Flutter Dev |
| Event creation modal (Flutter) | S | Must | Flutter Dev |

### Sprint 5-6: Tasks & AI (Week 5-6)

| Task | Effort | Priority | Owner |
|------|--------|----------|-------|
| Task recurrence (RRULE backend) | M | Must | Backend Dev |
| Task rotation preview endpoint | M | Must | Backend Dev |
| AI Planner real integration | M | Must | Backend + AI Dev |
| Rotation wizard UI | M | Must | Flutter Dev |
| Task detail modal with photo upload | M | Must | Flutter Dev |

### Sprint 7-8: Gamification & Auth (Week 7-8)

| Task | Effort | Priority | Owner |
|------|--------|----------|-------|
| Streak tracking service | M | Must | Backend Dev |
| Badge awarding rules + API | M | Must | Backend Dev |
| Shop redemption flow | M | Must | Backend Dev |
| Gamification HUD (Flutter) | M | Must | Flutter Dev |
| Badge award animation | S | Must | Flutter Dev |
| Apple SSO implementation | M | Must | Backend + iOS Dev |
| 2FA enforcement flow | S | Must | Backend Dev |

### Sprint 9-10: i18n & Themes (Week 9-10)

| Task | Effort | Priority | Owner |
|------|--------|----------|-------|
| Flutter intl setup (7 locales) | M | Should | Flutter Dev |
| Translation files (NL/EN/DE/FR) | M | Should | Content + Dev |
| Theme engine (4 variants) | M | Should | Flutter Dev |
| RTL support for AR | S | Should | Flutter Dev |
| Profile settings screen | S | Should | Flutter Dev |

### Sprint 11-12: Notifications & Polish (Week 11-12)

| Task | Effort | Priority | Owner |
|------|--------|----------|-------|
| FCM/APNs sender service | M | Should | Backend Dev |
| Push notification handler (Flutter) | M | Should | Flutter Dev |
| WebPush logic | S | Could | Backend Dev |
| Kiosk PIN system | S | Should | Backend + Flutter Dev |
| Photo proof + approval flow | M | Should | Backend + Flutter Dev |
| Child account setup wizard | M | Should | Flutter Dev |

### Sprint 13-14: Homework Coach (Week 13-14)

| Task | Effort | Priority | Owner |
|------|--------|----------|-------|
| StudyItem + StudySession models + APIs | L | Could | Backend Dev |
| Backward planning service | M | Could | AI/Backend Dev |
| Micro-quiz generation | M | Could | AI/Backend Dev |
| Huiswerkcoach UI (create/view/quiz) | L | Could | Flutter Dev |

### Sprint 15-16: Voice & Testing (Week 15-16)

| Task | Effort | Priority | Owner |
|------|--------|----------|-------|
| STT integration (OpenRouter) | M | Could | AI/Backend Dev |
| NLU intent parser (7 locales) | L | Could | AI/Backend Dev |
| TTS integration | S | Could | AI/Backend Dev |
| Voice UI enhancements | S | Could | Flutter Dev |
| E2E testing (critical flows) | M | Must | QA + Dev |
| Performance testing (sync + API) | M | Must | QA + Dev |

---

## 12. Success Metrics for Gap Closure

Track these to measure MVP readiness:

| Metric | Current | MVP Target | Phase 2 Target |
|--------|---------|------------|----------------|
| Database tables implemented | 9 | 16 | 18 |
| API endpoints | ~15 | 40+ | 60+ |
| Flutter screens (functional) | 7 | 20+ | 30+ |
| i18n locales | 0 | 4 (NL/EN/DE/FR) | 7 (+ TR/PL/AR) |
| Theme variants | 0 | 2 (minimal/dark) | 4 (+ cartoony/classy) |
| SSO providers | 3 | 4 (+ Apple) | 4 |
| AI services integrated | 0 | 2 (Planner/Vision) | 5 (+ STT/TTS/NLU) |
| Gamification loops active | 0 | 3 (streaks/badges/shop) | 5 (+ quests/challenges) |
| Test coverage (backend) | ~10% | 70%+ | 80%+ |
| Test coverage (frontend) | ~5% | 60%+ | 75%+ |

---

## Appendix A: Detailed Feature Comparison Table

| PRD Feature | PRD Detail | Current Status | Gap Severity | Notes |
|-------------|-----------|----------------|--------------|-------|
| **Kalender - Maand View** | Grid with events, color-coded per user | 🔴 MISSING | Critical | Core use case |
| **Kalender - Week View** | 7-day horizontal scroll, time slots | 🔴 MISSING | Critical | Core use case |
| **Kalender - Dag View** | Single day with hourly slots | 🔴 MISSING | High | Less critical than month/week |
| **Kalender - ICS Export** | Download family calendar as .ics | 🔴 MISSING | Medium | Phase 2 acceptable |
| **Kalender - Subscribe** | Google/Outlook read-only subscribe | 🔴 MISSING | Low | Phase 2 |
| **Taken - Eenmalig** | Single task with due date | ✅ DONE | None | Working |
| **Taken - Terugkerend (RRULE)** | Daily/weekly/custom recurrence | 🔴 MISSING | Critical | Differentiator |
| **Taken - Roulatie (round-robin)** | Auto-assign next person | 🔴 MISSING | High | Fairness feature |
| **Taken - Roulatie (fairness)** | AI-based load balancing | 🔴 MISSING | Critical | Core AI feature |
| **Taken - Claimbare pool** | Kids claim tasks, TTL lock | 🔴 MISSING | High | Autonomy feature |
| **Taken - Foto bewijs** | Upload photo on completion | 🔴 MISSING | High | Anti-cheat |
| **Taken - Ouder approve** | Parent review before done | 🔴 MISSING | Medium | Quality control |
| **Taken - Overdue handling** | Auto-nudge, penalty points | 🔴 MISSING | Medium | Motivation loop |
| **Gamification - Punten** | Award points on completion | 🟡 PARTIAL | High | Model exists, no logic |
| **Gamification - Streaks** | Daily completion tracking | 🔴 MISSING | Critical | Kids motivation |
| **Gamification - Badges** | Milestone achievements | 🟡 PARTIAL | High | Model exists, no logic |
| **Gamification - Shop** | Redeem points for rewards | 🟡 PARTIAL | High | UI exists, no backend |
| **Gamification - Persona-specific** | Boys/girls/teens different UX | 🔴 MISSING | Medium | Differentiation |
| **Gamification - Anti-cheat** | Rate limits, photo required | 🔴 MISSING | High | Economy protection |
| **AI Planner - Weekplan** | LLM-generated task distribution | 🔴 STUB | Critical | Core AI feature |
| **AI Planner - Fairness** | Load balancing by age/schedule | 🔴 MISSING | Critical | Core value prop |
| **AI Vision - Surface detect** | Glass/wood/textiel detection | 🔴 STUB | High | Differentiator |
| **AI Vision - Stain detect** | Vet/kalk/inkt/bloed detection | 🔴 STUB | High | Differentiator |
| **AI Vision - Cleaning steps** | Stappenplan with middelen | 🔴 STUB | High | Differentiator |
| **AI Voice - ASR** | Speech-to-text (7 locales) | 🔴 MISSING | Medium | Accessibility |
| **AI Voice - NLU** | Intent parsing | 🔴 MISSING | Medium | Convenience |
| **AI Voice - TTS** | Text-to-speech feedback | 🔴 MISSING | Low | Nice-to-have |
| **Huiswerkcoach - Backward plan** | AI study schedule from toets date | 🔴 MISSING | Medium | Phase 2 acceptable |
| **Huiswerkcoach - Sessions** | 20-30m study blocks | 🔴 MISSING | Medium | Phase 2 acceptable |
| **Huiswerkcoach - Micro-quiz** | 3-5 daily questions, spaced rep | 🔴 MISSING | Medium | Phase 2 acceptable |
| **SSO - Google** | OAuth 2.0 login | ✅ DONE | None | Working |
| **SSO - Microsoft** | OAuth 2.0 login | ✅ DONE | None | Working |
| **SSO - Facebook** | OAuth 2.0 login | ✅ DONE | None | Working |
| **SSO - Apple** | Sign in with Apple | 🔴 MISSING | Critical | iOS requirement |
| **2FA - TOTP** | Authenticator app | 🟡 PARTIAL | High | Setup exists, no enforcement |
| **2FA - Email OTP** | One-time password via email | 🔴 MISSING | Medium | Alternative to TOTP |
| **2FA - SMS OTP** | One-time password via SMS | 🔴 MISSING | Low | Optional |
| **Child Accounts - PIN** | Parent creates child with PIN | 🔴 MISSING | High | Safety feature |
| **Child Accounts - Permissions** | Toggle childCanCreateTasks etc | 🔴 MISSING | Medium | Flexibility |
| **RBAC - parent** | Full control | 🟡 PARTIAL | Medium | Role exists, no enforcement |
| **RBAC - teen** | View + create study items | 🟡 PARTIAL | Medium | Role exists, no enforcement |
| **RBAC - child** | Limited view, assigned tasks only | 🟡 PARTIAL | High | Role exists, no enforcement |
| **RBAC - helper** | Assigned tasks only, photo optional | 🟡 PARTIAL | Low | Role exists, no enforcement |
| **i18n - NL** | Dutch translation | 🔴 MISSING | Critical | Primary market |
| **i18n - EN** | English translation | 🔴 MISSING | Critical | International |
| **i18n - DE** | German translation | 🔴 MISSING | High | EU market |
| **i18n - FR** | French translation | 🔴 MISSING | High | EU market |
| **i18n - TR** | Turkish translation | 🔴 MISSING | Medium | Community demand |
| **i18n - PL** | Polish translation | 🔴 MISSING | Medium | Community demand |
| **i18n - AR** | Arabic translation (RTL) | 🔴 MISSING | Medium | MENA market |
| **Themes - cartoony** | Kids 6-10 theme | 🔴 MISSING | High | Persona targeting |
| **Themes - minimal** | Default clean theme | 🟡 PARTIAL | Medium | Field exists, no styling |
| **Themes - classy** | Parents professional theme | 🔴 MISSING | Medium | Persona targeting |
| **Themes - dark** | Teens dark mode | 🔴 MISSING | High | Persona targeting |
| **Offline-first - Hive** | Local encrypted storage | 🔴 MISSING | Critical | MVP requirement |
| **Offline-first - Sync** | Delta sync with conflict resolution | 🔴 MISSING | Critical | MVP requirement |
| **Offline-first - Optimistic UI** | Immediate feedback | 🟡 PARTIAL | High | Basic queue exists |
| **Kiosk - PIN exit** | Parent PIN to exit fullscreen | 🔴 MISSING | High | Safety feature |
| **Kiosk - Auto-refresh** | Polling for updates | 🔴 MISSING | Medium | UX improvement |
| **Kiosk - /today route** | Dedicated endpoint | 🔴 MISSING | Low | Can use /tasks |
| **Push - FCM** | Android push notifications | 🔴 MISSING | High | Engagement |
| **Push - APNs** | iOS push notifications | 🔴 MISSING | High | Engagement |
| **Push - WebPush** | Browser notifications | 🔴 MISSING | Low | Phase 2 |
| **Push - Streak guard** | Daily 20:00 reminder | 🔴 MISSING | High | Retention feature |
| **Monetisatie - Gratis ads** | Kindveilige ads in parent views | 🔴 MISSING | Medium | Revenue stream |
| **Monetisatie - Family Unlock** | One-time IAP | 🔴 MISSING | High | Revenue stream |
| **Monetisatie - Premium** | Monthly/yearly subscription | 🔴 MISSING | High | Revenue stream |
| **AVG - Data export** | JSON/CSV download | 🔴 MISSING | High | Legal requirement |
| **AVG - Right to be forgotten** | Account + data deletion | 🔴 MISSING | High | Legal requirement |
| **AVG - PII-scrub to AI** | Pseudonimization before API call | 🔴 MISSING | Critical | Privacy by design |
| **COPPA - Parental consent** | Explicit consent for child accounts | 🔴 MISSING | Critical | US compliance |

**Summary:**
- ✅ DONE: 6 features (7%)
- 🟡 PARTIAL: 12 features (14%)
- 🔴 MISSING: 67 features (79%)

---

## Appendix B: Resource Requirements

### Team Composition (Recommended):

- **1x Tech Lead** (architecture, code review, DevOps)
- **2x Backend Developer** (Python/FastAPI, PostgreSQL, OpenRouter integration)
- **2x Flutter Developer** (Dart, offline-first, state management)
- **1x AI/ML Engineer** (OpenRouter models, prompt engineering, NLU)
- **1x UI/UX Designer** (persona-specific design, theme system, i18n)
- **1x QA Engineer** (test automation, security testing, load testing)
- **0.5x Content Writer** (translations, PRD refinement)
- **0.5x Product Manager** (stakeholder coordination, prioritization)

**Total:** 9 FTE

### Timeline Estimates:

- **Minimal MVP (critical features only):** 12-16 weeks (2x Backend + 2x Flutter + 1x AI)
- **Full MVP (all Must + Should):** 20-24 weeks (full team)
- **Phase 2 (Homework Coach, Voice, etc.):** +12 weeks
- **Production Launch:** 6 months from start (with full team)

### Infrastructure Costs (Monthly):

- **OpenRouter API:** $200-500 (depends on usage)
- **Firebase Hosting + FCM:** $50-100
- **PostgreSQL (managed):** $100-200
- **Redis (managed):** $50-100
- **S3 storage:** $20-50
- **Domain + SSL:** $10
- **Monitoring (Sentry):** $26-80

**Total:** ~$450-1100/month

---

**End of Gap Analysis Report**
