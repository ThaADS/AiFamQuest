# FamQuest — CLAUDE.md
## AI-Gezinsplanner Implementation Guide v2.1

> **Project Status**: Active Development | **PRD Version**: 2.1 | **Architecture**: Flutter + FastAPI + PostgreSQL
> **AI Layer**: OpenRouter | **Target Platforms**: iOS, Android, Web (PWA)

---

## 📋 Executive Overview

**FamQuest** is an AI-powered family planning application combining:
- **Shared calendar** with family events and task scheduling
- **Gamification system** tailored per age group (kids/teens/parents)
- **AI-powered features**: task planning, homework coach, vision cleaning tips, voice commands
- **Offline-first architecture** with sync conflict resolution
- **Multi-role system**: parent/teen/child/external helper with RBAC
- **SSO authentication**: Apple/Google/Microsoft/Facebook + email + 2FA
- **Multi-language support**: NL/EN/DE/FR/TR/PL/AR (with RTL)
- **Kiosk mode**: PWA for shared family displays

---

## 🎯 Development Strategy & Agent Orchestration

### Phase-Based Implementation Approach

```yaml
phase_1_foundation:
  priority: CRITICAL
  scope: Core infrastructure, data models, basic CRUD
  agent_primary: backend-architect, system-architect
  mcp_tools: [serena, sequential, context7]

phase_2_mvp_features:
  priority: HIGH
  scope: Calendar, tasks, basic gamification, auth
  agent_primary: frontend-architect, backend-architect
  mcp_tools: [magic, sequential, context7, serena]

phase_3_ai_integration:
  priority: HIGH
  scope: AI planner, vision tips, voice commands, homework coach
  agent_primary: python-expert, system-architect
  mcp_tools: [sequential, tavily, context7]

phase_4_advanced_features:
  priority: MEDIUM
  scope: Advanced gamification, kiosk, i18n, offline sync
  agent_primary: frontend-architect, performance-engineer
  mcp_tools: [magic, morphllm, serena]

phase_5_polish:
  priority: MEDIUM
  scope: Testing, optimization, security hardening
  agent_primary: quality-engineer, security-engineer, performance-engineer
  mcp_tools: [playwright, sequential]
```

---

## 🏗️ Architecture Blueprint

### Technology Stack

```yaml
frontend:
  framework: Flutter 3.x (Dart)
  platforms: [iOS, Android, Web_PWA]
  state_management: Riverpod
  routing: go_router
  storage: flutter_secure_storage + Hive (encrypted)
  offline: delta-sync with conflict resolution

backend:
  framework: FastAPI (Python 3.11+)
  database: PostgreSQL 15+
  cache: Redis 7+
  migrations: Alembic
  storage: S3-compatible (media files)

ai_layer:
  broker: OpenRouter
  services:
    - llm_planner: Task scheduling and fairness distribution
    - vision_tips: Photo → cleaning advice (OpenAI Vision / GPT-4V)
    - voice_stt: Speech-to-text (Whisper via OpenRouter)
    - voice_tts: Text-to-speech
    - nlu_intent: Voice command parsing
    - study_coach: Homework planning + micro-quizzes

auth:
  sso_providers: [Apple, Google, Microsoft, Facebook]
  email_password: true
  two_factor: [TOTP, Email_OTP, SMS_OTP]

notifications:
  push: FCM (Android/Web) + APNs (iOS)
  email: SendGrid / Mailgun

deployment:
  web: Firebase Hosting / Cloudflare
  api: GCP / AWS / K8s
  ci_cd: GitHub Actions + Codemagic (mobile)
  monitoring: Sentry + Crashlytics + ELK
```

---

## 📊 Data Model & Database Architecture

### Core Entities (PostgreSQL)

```mermaid
erDiagram
  FAMILY ||--o{ USER : has
  FAMILY ||--o{ TASK : has
  FAMILY ||--o{ EVENT : has
  FAMILY ||--o{ REWARD : defines
  USER ||--o{ POINTS_LEDGER : earns
  USER ||--o{ BADGE : earns
  USER ||--o{ STUDY_ITEM : creates
  USER ||--o{ DEVICE_TOKEN : registers
  STUDY_ITEM ||--o{ STUDY_SESSION : schedules
  TASK ||--o{ TASK_LOG : logs
  TASK ||--o{ MEDIA : attaches
```

### Database Tables (Detailed)

#### **Family**
```python
- id: UUID (PK)
- name: String
- plan: String (free|family_unlock|premium)
- createdAt: Timestamp
```

#### **User**
```python
- id: UUID (PK)
- familyId: UUID (FK → families.id)
- email: String (unique, indexed)
- displayName: String
- role: Enum(parent|teen|child|helper)
- passwordHash: String (nullable for SSO-only)
- locale: Enum(nl|en|de|fr|tr|pl|ar)
- theme: Enum(cartoony|minimal|classy|dark|custom)
- avatar: String (URL or preset code)
- permissions: JSONB {childCanCreateTasks, childCanCreateStudyItems}
- sso: JSONB {providers: [], emailVerified, 2faEnabled}
- twoFASecret: String (TOTP secret, encrypted)
- twoFAEnabled: Boolean
- createdAt: Timestamp
- updatedAt: Timestamp
```

#### **Task**
```python
- id: UUID (PK)
- familyId: UUID (FK, indexed)
- title: String
- desc: Text
- category: Enum(cleaning|care|pet|homework|other)
- frequency: String (none|daily|weekly|cron)
- rrule: String (iCal RRULE for recurrence)
- due: Timestamp (nullable)
- assignees: UUID[] (array of user IDs)
- claimable: Boolean (task pool feature)
- claimedBy: UUID (nullable, with TTL)
- claimExpiry: Timestamp (nullable)
- points: Integer (default 10)
- photoRequired: Boolean
- parentApproval: Boolean
- status: Enum(open|pendingApproval|done)
- proofPhotos: String[] (S3 URLs)
- priority: Enum(low|med|high)
- estDuration: Integer (minutes)
- createdBy: UUID
- createdAt: Timestamp
- updatedAt: Timestamp
- version: Integer (optimistic locking)
```

#### **Event** (Calendar)
```python
- id: UUID (PK)
- familyId: UUID (FK)
- title: String
- desc: Text
- startTime: Timestamp
- endTime: Timestamp
- allDay: Boolean
- rrule: String (nullable, for recurring events)
- attendees: UUID[] (user IDs)
- color: String (hex color per user)
- location: String (nullable)
- createdBy: UUID
- createdAt: Timestamp
- updatedAt: Timestamp
```

#### **PointsLedger**
```python
- id: UUID (PK)
- userId: UUID (indexed)
- familyId: UUID (indexed)
- delta: Integer (can be negative for penalties)
- reason: String
- taskId: UUID (nullable, if from task completion)
- multiplier: Float (on_time, quality, streak bonuses)
- createdAt: Timestamp
```

#### **Badge**
```python
- id: UUID (PK)
- userId: UUID (indexed)
- code: String (badge identifier: first_task|week_streak|speed_demon|etc)
- metadata: JSONB (tier, progress, custom data)
- awardedAt: Timestamp
```

#### **Reward** (Shop)
```python
- id: UUID (PK)
- familyId: UUID (FK)
- name: String
- desc: Text
- cost: Integer (points required)
- icon: String (emoji or image URL)
- category: Enum(avatar|theme|perk|custom)
- active: Boolean
- createdAt: Timestamp
```

#### **StudyItem** (Homework Coach)
```python
- id: UUID (PK)
- userId: UUID (FK)
- subject: String
- topic: String
- examDate: Timestamp
- difficulty: Enum(easy|medium|hard)
- status: Enum(planning|active|completed)
- aiPlan: JSONB (backward planning sessions)
- createdAt: Timestamp
- updatedAt: Timestamp
```

#### **StudySession**
```python
- id: UUID (PK)
- studyItemId: UUID (FK)
- scheduledAt: Timestamp
- duration: Integer (minutes)
- completed: Boolean
- quizResults: JSONB (micro-quiz scores)
- createdAt: Timestamp
```

#### **DeviceToken** (Push Notifications)
```python
- id: UUID (PK)
- userId: UUID (indexed)
- platform: Enum(ios|android|web)
- token: String (FCM/APNs token)
- createdAt: Timestamp
- updatedAt: Timestamp
```

#### **WebPushSub** (Web Push)
```python
- id: UUID (PK)
- userId: UUID (indexed)
- endpoint: String
- p256dh: String (encryption key)
- auth: String (authentication secret)
- createdAt: Timestamp
```

#### **AuditLog** (Security & Compliance)
```python
- id: UUID (PK)
- actorUserId: UUID (who performed action)
- familyId: UUID (indexed)
- action: String (task_created|task_completed|user_invited|etc)
- meta: JSONB (additional context)
- createdAt: Timestamp
```

#### **Media** (Photos, attachments)
```python
- id: UUID (PK)
- familyId: UUID (FK)
- uploadedBy: UUID (FK)
- type: Enum(photo|document|avatar)
- s3Key: String
- url: String (presigned URL, short-lived)
- virusScan: Enum(pending|clean|infected)
- createdAt: Timestamp
- expiresAt: Timestamp (data retention policy)
```

---

## 🔐 Security & Access Control

### Role-Based Access Control (RBAC)

```yaml
parent:
  permissions:
    - create:any [task, event, reward, study_item]
    - update:any [task, event, reward, user_permissions]
    - delete:any [task, event, reward]
    - approve:task_completion
    - manage:family_settings
    - view:all_family_data
    - invite:users

teen:
  permissions:
    - view:family [tasks, events]
    - create:own [study_items]
    - update:own [profile, study_sessions]
    - complete:assigned_tasks
    - claim:claimable_tasks
    - spend:points (shop)

child:
  permissions:
    - view:own [tasks, events]
    - complete:assigned_tasks
    - claim:claimable_tasks (if enabled)
    - spend:points (shop, parental approval optional)
  configurable:
    - create:own_tasks (parent toggle)
    - view:family_calendar (parent toggle)

helper:
  permissions:
    - view:assigned_tasks_only
    - complete:assigned_tasks
    - upload:photo_proof (optional)
  restrictions:
    - no_access:family_data
    - no_access:calendar
    - no_access:gamification
```

### Authentication Flow

```yaml
sso_flow:
  1. User clicks "Sign in with [Provider]"
  2. Redirect to provider (Apple/Google/MS/Facebook)
  3. Provider consent → callback with auth code
  4. Exchange code for provider tokens
  5. Create/link user account → issue JWT tokens
  6. If 2FA enabled: require TOTP/OTP verification

email_password_flow:
  1. User enters email + password
  2. Backend validates credentials
  3. If 2FA enabled: require TOTP/OTP
  4. Issue JWT (access + refresh tokens)

child_account_flow:
  1. Parent invites child via email or in-app
  2. Child sets PIN (4-6 digits, no email required)
  3. Parent manages permissions via toggle
  4. Child logs in with PIN only
```

### Security Standards

```yaml
compliance:
  - AVG: PII minimization, right to be forgotten, data export
  - COPPA: Parental consent for <13, no ads in child views
  - OWASP_MASVS: Mobile app security verification

encryption:
  - transport: TLS 1.2+ (HTTPS-only)
  - at_rest: PostgreSQL encryption, S3 encryption
  - device: flutter_secure_storage for tokens

anti_abuse:
  - rate_limiting: 100 req/min per user
  - photo_required: For suspicious fast completions
  - parent_approval: Heuristic triggers (e.g., 10 tasks in 5 min)
  - audit_logging: All sensitive actions logged
```

---

## 🤖 AI Integration via OpenRouter

### AI Services Architecture

```yaml
openrouter_config:
  base_url: https://openrouter.ai/api/v1
  api_key: env.OPENROUTER_API_KEY
  fallback_strategy: true
  timeout: 30s
  retry: 3
```

### 1. AI Planner (Task Scheduling)

**Purpose**: Generate weekly task distribution with fairness algorithm

**Input**:
```json
{
  "familyId": "uuid",
  "users": [
    {"id": "uuid-noah", "role": "child", "age": 10, "workload": 0.28},
    {"id": "uuid-luna", "role": "child", "age": 8, "workload": 0.24}
  ],
  "tasks": [
    {"title": "Vaatwasser", "category": "cleaning", "estDuration": 15, "frequency": "daily"}
  ],
  "calendar": [
    {"userId": "uuid-noah", "date": "2025-11-17", "events": ["Training 18:00-19:30"]}
  ],
  "constraints": {
    "maxTasksPerDay": 3,
    "respectBusyHours": true,
    "rotationStrategy": "fairness"
  }
}
```

**Model**: `anthropic/claude-3.5-sonnet` or `openai/gpt-4o`

**Output**:
```json
{
  "weekPlan": [
    {
      "date": "2025-11-17",
      "tasks": [
        {
          "taskId": "uuid-task",
          "title": "Vaatwasser",
          "assignee": "uuid-noah",
          "suggestedTime": "2025-11-17T17:00:00Z",
          "reason": "Available before training, light load today"
        }
      ]
    }
  ],
  "fairness": {
    "distribution": {
      "uuid-noah": 0.28,
      "uuid-luna": 0.24,
      "uuid-sam": 0.22,
      "uuid-eva": 0.13,
      "uuid-mark": 0.13
    },
    "notes": "Balanced by age, agenda, and workload capacity"
  }
}
```

### 2. Vision Tips (Photo → Cleaning Advice)

**Purpose**: Analyze photos of stains/surfaces and provide cleaning guidance

**Input**:
```json
{
  "image_url": "https://famquest.s3.../stain_photo.jpg",
  "context": {
    "room": "kitchen",
    "surface": "countertop",
    "user_input": "Red wine stain on marble"
  }
}
```

**Model**: `openai/gpt-4-vision-preview`

**Output**:
```json
{
  "detected": {
    "surface": "marble",
    "stain": "red_wine",
    "confidence": 0.87
  },
  "steps": [
    "Blot immediately with paper towel (don't rub)",
    "Mix baking soda + water → paste",
    "Apply paste, let sit 10 min",
    "Wipe with damp cloth",
    "Dry with clean towel"
  ],
  "products": {
    "recommended": ["Baking soda", "White vinegar (diluted)"],
    "avoid": ["Bleach", "Acidic cleaners (lemon)"]
  },
  "warnings": ["Marble is porous, act fast", "Test on hidden area first"],
  "estimatedMinutes": 15,
  "difficulty": 2
}
```

### 3. Voice Commands (STT + NLU + TTS)

**Pipeline**:
```
User speech → STT (Whisper) → NLU (intent parsing) → Action → TTS (response)
```

**Example Intents** (NL):
```yaml
create_task:
  patterns:
    - "Maak taak [TITLE] [DATETIME] voor [USER]"
    - "Voeg toe [TITLE] aan de lijst"
  slots:
    title: String
    datetime: Timestamp (parsed via NLU)
    assignee: User (matched by name)

mark_done:
  patterns:
    - "Markeer [TITLE] als klaar"
    - "[TITLE] is gedaan"
  slots:
    title: String (fuzzy match to open tasks)

show_tasks:
  patterns:
    - "Wat moet ik vandaag doen?"
    - "Laat mijn taken zien"
  response: List of user's tasks
```

**Models**:
- STT: `openai/whisper-1` (via OpenRouter)
- NLU: `anthropic/claude-3-haiku` (fast intent parsing)
- TTS: Web Speech API (browser) or `openai/tts-1` (API)

### 4. Homework Coach (Study Planner + Micro-Quizzes)

**Purpose**: Backward planning from exam date + spaced repetition quizzes

**Input**:
```json
{
  "userId": "uuid-sam",
  "subject": "Biology",
  "topic": "Cell structure, photosynthesis, mitosis",
  "examDate": "2025-11-25T09:00:00Z",
  "difficulty": "medium",
  "availableTime": 30
}
```

**Model**: `anthropic/claude-3.5-sonnet`

**Output**:
```json
{
  "plan": [
    {
      "date": "2025-11-17",
      "duration": 30,
      "focus": "Cell structure basics",
      "tasks": ["Read chapter 3", "Draw cell diagram", "5-min quiz"]
    },
    {
      "date": "2025-11-19",
      "duration": 30,
      "focus": "Photosynthesis process",
      "tasks": ["Watch video", "Summary notes", "5-min quiz"]
    }
  ],
  "milestones": [
    {"date": "2025-11-21", "checkpoint": "Parent quiz: cell + photosynthesis"},
    {"date": "2025-11-24", "checkpoint": "Final review + practice exam"}
  ],
  "quizzes": [
    {
      "date": "2025-11-17",
      "questions": [
        {"q": "What is the powerhouse of the cell?", "a": "Mitochondria", "type": "text"},
        {"q": "Name the green pigment in plants", "a": "Chlorophyll", "type": "text"}
      ]
    }
  ]
}
```

---

## 🎮 Gamification System (Per Persona)

### Point Economy

```yaml
base_points: 10
multipliers:
  on_time: 1.2 (completed before due time)
  quality_4star: 1.1 (parent approval rating)
  streak_week: 1.1 (7 consecutive days)
  overdue_penalty: 0.8 (late completion)

anti_cheat:
  min_interval_sec: 30 (between task completions)
  photo_required_trigger: >3 tasks in <10 min
  parent_approval_trigger: suspicious_patterns
```

### Badge System

```yaml
badges:
  first_task: "Awarded on first task completion"
  week_streak: "7 consecutive days with ≥1 task"
  speed_demon: "Task completed in <50% estimated time"
  perfectionist: "10 tasks with 5-star approval"
  helper_hero: "Completed task for sibling (claim from pool)"
  early_bird: "Task done before 08:00"
  night_owl: "Task done after 20:00"
```

### Persona-Specific Rewards

#### **Kids (6-10 years)**
```yaml
theme: cartoony
visuals: large_icons, bright_colors, sound_effects
rewards:
  - stickers: 50+ collectible designs
  - avatar_accessories: hats, glasses, pets
  - sound_packs: unlock funny completion sounds
feedback_loop: immediate_animation_on_completion
```

#### **Boys (10-15 years)**
```yaml
theme: space|tech
visuals: levels, tiers (bronze/silver/gold), leaderboards
rewards:
  - badges: challenge_badges (speed, combo, difficulty)
  - time_trials: compete against own best times
  - quests: weekly missions (e.g., "Complete 5 cleaning tasks")
feedback_loop: XP_bar + tier_progression
```

#### **Girls (10-15 years)**
```yaml
theme: pastel|stylish
visuals: collection_sets, spaarkaarten, combo_bonuses
rewards:
  - sticker_packs: themed collections (animals, fantasy)
  - avatar_customization: outfits, hairstyles, room_decor
  - completion_certificates: printable achievements
feedback_loop: progress_towards_set_completion
```

#### **Teens (15+ years)**
```yaml
theme: minimal|dark
visuals: clean_design, data_graphs, streak_counters
rewards:
  - streaks: maintain daily/weekly task completion
  - insights: personal productivity analytics
  - perks: unlock family privileges (e.g., "Pick movie night")
feedback_loop: minimal_notifications + weekly_summary
```

#### **Parents**
```yaml
theme: minimal|classy
visuals: calm_dashboards, fairness_charts
rewards:
  - peace_of_mind: automated reminders, less mental load
  - insights: who_does_what, fairness_distribution
  - digests: weekly_email_summary
feedback_loop: silent_unless_needed (exception-based notifications)
```

---

## 🌍 Internationalization (i18n) & RTL Support

### Supported Locales

```yaml
locales:
  - nl: Nederlands
  - en: English
  - de: Deutsch
  - fr: Français
  - tr: Türkçe
  - pl: Polski
  - ar: العربية (RTL)

rtl_locales: [ar]
per_user_language: true
icu_messageformat: true
```

### Implementation (Flutter)

```dart
// assets/i18n/en.json
{
  "task_create_title": "Create Task",
  "task_due_in": "Due in {days} {days, plural, one{day} other{days}}",
  "points_earned": "You earned {points} points!"
}

// lib/l10n/app_localizations.dart
class AppLocalizations {
  final Locale locale;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  String get taskCreateTitle => _translate('task_create_title');
  String taskDueIn(int days) => _translate('task_due_in', args: {'days': days});
}
```

---

## 📴 Offline-First Architecture & Sync

### Local Storage (Flutter)

```yaml
strategy: offline-first with optimistic UI
storage:
  - flutter_secure_storage: JWT tokens, sensitive data
  - Hive: Encrypted boxes for tasks, events, user data

sync_triggers:
  - app_resume: Auto-sync on app foreground
  - network_up: Detect network availability
  - interval: Every 5 minutes (configurable)
  - manual: Pull-to-refresh gesture
```

### Conflict Resolution

```yaml
rules:
  task_status:
    priority: done > pendingApproval > open
    reason: "Completion takes precedence over reopening"

  task_updates:
    strategy: last_writer_wins
    fallback: merge_if_possible (non-overlapping fields)

  event_updates:
    strategy: server_wins (prevent calendar chaos)
    exception: user_can_reject_server_change

optimistic_ui: true
undo_queue: local_actions_can_be_rolled_back
```

### Sync Flow

```mermaid
sequenceDiagram
  App->>LocalDB: Write change (optimistic)
  App->>UI: Update immediately
  App->>SyncQueue: Add to queue
  SyncQueue->>Backend: POST /sync/delta
  Backend-->>SyncQueue: Conflicts (if any)
  SyncQueue->>ConflictResolver: Apply rules
  ConflictResolver->>LocalDB: Merge resolved state
  LocalDB->>UI: Refresh if changed
```

---

## 🔔 Notification System

### Channels

```yaml
push:
  ios: APNs
  android: FCM
  web: Web Push API

email:
  transactional: SendGrid / Mailgun
  digests: Weekly parent summary

local:
  offline_reminders: Flutter local notifications
```

### Events

```yaml
task_reminders:
  - task_due_tminus_60: "Reminder: Task due in 1 hour"
  - task_due_now: "Urgent: Task is due now!"
  - task_overdue: "Overdue: Complete [task] ASAP"

family_updates:
  - task_completed: "[User] completed [task]"
  - approval_requested: "[Child] needs approval for [task]"
  - points_milestone: "[User] reached 500 points!"

streaks:
  - streak_guard_20h: "Keep your streak! Complete 1 task today"
  - streak_lost: "Your streak ended. Start a new one tomorrow!"
```

---

## 💰 Monetization Strategy

### Tiers

```yaml
free:
  includes:
    - unlimited_family_members: false (max 4)
    - tasks_calendar_basic: true
    - gamification_basic: true
    - ai_requests_per_day: 5
    - themes: 2 (cartoony + minimal)
    - ads: true (parent views only, kid-safe)

family_unlock:
  type: one_time_purchase
  price: €19.99 / $19.99
  includes:
    - unlimited_family_members: true
    - remove_ads: true
    - priority_support: email

premium:
  type: subscription (monthly/yearly)
  price: €4.99/month or €49.99/year
  includes:
    - all_family_unlock_features: true
    - ai_unlimited: true
    - all_themes: true
    - advanced_analytics: true
    - priority_support: live_chat
    - early_access: new_features
```

---

## 🧪 Testing Strategy

### Test Pyramid

```yaml
unit_tests:
  backend:
    - pytest: API endpoints, AI service mocks
    - coverage_target: 80%
  flutter:
    - flutter_test: Widget tests, business logic
    - coverage_target: 75%

integration_tests:
  - widget_integration: Multi-screen flows
  - api_integration: End-to-end API calls
  - offline_sync: Conflict resolution scenarios

e2e_tests:
  tools: [Playwright (web), Flutter Driver (mobile)]
  scenarios:
    - user_onboarding: SSO → profile setup → first task
    - task_lifecycle: Create → assign → complete → approve
    - gamification: Earn points → buy reward → check badge

performance_tests:
  - load_testing: 1000 concurrent users (Locust)
  - mobile_profiling: Flutter DevTools (jank detection)

security_tests:
  - owasp_scan: Automated vulnerability scan
  - pentest: Manual security audit (pre-launch)
```

---

## 🚀 Deployment & CI/CD

### Pipeline (GitHub Actions + Codemagic)

```yaml
on_push_main:
  jobs:
    backend_tests:
      runs-on: ubuntu-latest
      steps:
        - checkout
        - setup_python_3.11
        - pip_install_requirements
        - pytest_with_coverage
        - upload_coverage_to_codecov

    flutter_tests:
      runs-on: ubuntu-latest
      steps:
        - checkout
        - setup_flutter_3.x
        - flutter_pub_get
        - flutter_test

    deploy_backend:
      needs: backend_tests
      runs-on: ubuntu-latest
      steps:
        - docker_build_push
        - deploy_to_gcp_cloudrun

    deploy_web:
      needs: flutter_tests
      runs-on: ubuntu-latest
      steps:
        - flutter_build_web
        - deploy_to_firebase_hosting

on_tag_release:
  jobs:
    build_mobile:
      uses: codemagic/build@v1
      with:
        platforms: [ios, android]
        flavor: production
      steps:
        - build_ios_release
        - submit_to_testflight
        - build_android_release
        - submit_to_playstore_beta
```

---

## 🛠️ Development Workflow with SuperClaude Framework

### Agent & MCP Integration Matrix

| **Task Type** | **Primary Agent** | **MCP Tools** | **Rationale** |
|---------------|-------------------|---------------|---------------|
| Database schema design | backend-architect | serena, sequential | Semantic understanding + structured reasoning |
| API endpoint implementation | python-expert | context7, sequential | Official FastAPI patterns + error handling |
| Flutter UI components | frontend-architect | magic, context7 | 21st.dev patterns + Flutter best practices |
| AI service integration | python-expert, system-architect | tavily, sequential | Research OpenRouter docs + integration strategy |
| Gamification logic | frontend-architect, quality-engineer | sequential, serena | Complex business rules + test coverage |
| Offline sync | performance-engineer | sequential, serena | Conflict resolution algorithms + optimization |
| i18n implementation | frontend-architect | morphllm | Bulk text replacements across files |
| Security audit | security-engineer | sequential, playwright | Systematic threat modeling + E2E testing |
| Performance optimization | performance-engineer | sequential, playwright | Profiling + load testing |

### Development Patterns

#### 🔹 **Pattern 1: Feature Implementation (Full Cycle)**

```bash
# Step 1: Research & Planning
/sc:research "Flutter offline-first architecture best practices"
# → Activates deep-research-agent with Tavily

# Step 2: Design
/sc:design offline_sync_service
# → Activates system-architect with Sequential for structured design

# Step 3: Implementation
/sc:implement offline_sync --test-driven
# → Activates appropriate specialist + TDD skill

# Step 4: Review
# → Activates code-reviewer agent automatically post-implementation

# Step 5: Testing
/sc:test offline_sync --coverage
# → Activates quality-engineer with Playwright
```

#### 🔹 **Pattern 2: Bug Fix (Systematic Debugging)**

```bash
# Trigger: Test failure or production error
# Auto-activates: root-cause-analyst + systematic-debugging skill

# Step 1: Investigation
/sc:troubleshoot "Task sync conflicts overwriting local changes"

# Step 2: Hypothesis Testing
# Sequential MCP: Multi-step reasoning through conflict scenarios

# Step 3: Fix Implementation
# → Python-expert or frontend-architect based on root cause

# Step 4: Verification
# → Quality-engineer validates fix with regression tests
```

#### 🔹 **Pattern 3: Refactoring (Code Quality)**

```bash
# Step 1: Analysis
/sc:analyze backend/routers/tasks.py --focus quality,performance

# Step 2: Refactoring
# → Activates refactoring-expert with Morphllm (pattern-based edits)

# Step 3: Validation
# → Quality-engineer ensures no regression (tests still pass)
```

---

## 📋 Implementation Roadmap (Phased)

### **Phase 1: Foundation (Weeks 1-3)**

```yaml
priority: CRITICAL
tasks:
  - setup_repository_structure:
      backend: FastAPI project structure
      flutter: lib/ feature-based organization
      ci_cd: GitHub Actions + Codemagic config

  - database_schema:
      agent: backend-architect
      mcp: [serena, sequential]
      deliverables:
        - PostgreSQL schema (all tables)
        - Alembic migrations (0001_initial.py)
        - SQLAlchemy models (core/models.py)

  - auth_system:
      agent: security-engineer, python-expert
      mcp: [context7, sequential]
      deliverables:
        - Email + password login
        - JWT token management (access + refresh)
        - RBAC middleware (parent/teen/child/helper)
        - Basic 2FA (TOTP setup)

  - api_crud_basics:
      agent: python-expert
      mcp: [context7]
      deliverables:
        - /families CRUD
        - /users CRUD
        - /tasks CRUD
        - /events CRUD
        - OpenAPI documentation

  - flutter_scaffolding:
      agent: frontend-architect
      mcp: [magic, context7]
      deliverables:
        - Riverpod state management setup
        - go_router navigation
        - API client (lib/api/client.dart)
        - Auth screens (login, register)
```

### **Phase 2: MVP Features (Weeks 4-7)**

```yaml
priority: HIGH
tasks:
  - calendar_module:
      agent: frontend-architect
      mcp: [magic, context7]
      deliverables:
        - Month/Week/Day views
        - Event CRUD UI
        - Color-coded per user
        - Sync with backend

  - task_management:
      agent: frontend-architect, python-expert
      mcp: [magic, sequential]
      deliverables:
        - Task list UI (filtered by role)
        - Task detail screen
        - Photo upload (image_picker)
        - Task completion flow
        - Parent approval UI

  - gamification_basic:
      agent: frontend-architect
      mcp: [magic, sequential]
      deliverables:
        - Points ledger backend
        - Points display HUD (Flutter)
        - Badge system (award logic + UI)
        - Basic shop (rewards CRUD)
        - Persona-specific themes (cartoony, minimal)

  - sso_integration:
      agent: security-engineer, python-expert
      mcp: [context7, tavily]
      deliverables:
        - Google Sign-In (OAuth 2.0)
        - Apple Sign-In (Sign in with Apple)
        - Microsoft (Azure AD)
        - Facebook Login
        - Account linking logic
```

### **Phase 3: AI Integration (Weeks 8-10)**

```yaml
priority: HIGH
tasks:
  - openrouter_setup:
      agent: python-expert, system-architect
      mcp: [tavily, context7]
      deliverables:
        - OpenRouter client (core/ai_client.py)
        - Model fallback strategy
        - Rate limiting + quota management

  - ai_task_planner:
      agent: python-expert
      mcp: [sequential, tavily]
      deliverables:
        - /ai/plan endpoint
        - Prompt engineering (fairness algorithm)
        - Weekly plan JSON output
        - Parent review UI (Flutter)

  - vision_cleaning_tips:
      agent: python-expert
      mcp: [sequential]
      deliverables:
        - /ai/vision-tips endpoint
        - Photo upload → OpenAI Vision
        - Step-by-step cleaning advice
        - Safety warnings

  - voice_commands:
      agent: frontend-architect, python-expert
      mcp: [context7, sequential]
      deliverables:
        - STT integration (Whisper via OpenRouter)
        - NLU intent parsing (Claude Haiku)
        - Voice task creation
        - TTS feedback
        - Multi-language support (NL/EN/DE/FR)

  - homework_coach:
      agent: python-expert
      mcp: [sequential]
      deliverables:
        - StudyItem CRUD
        - Backward planning algorithm
        - Micro-quiz generator
        - Spaced repetition logic
        - Study session UI (Flutter)
```

### **Phase 4: Advanced Features (Weeks 11-14)**

```yaml
priority: MEDIUM
tasks:
  - offline_sync:
      agent: performance-engineer, frontend-architect
      mcp: [serena, sequential]
      deliverables:
        - Hive encrypted storage
        - Delta sync algorithm
        - Conflict resolution rules
        - Optimistic UI updates
        - Sync queue + retry logic

  - kiosk_mode:
      agent: frontend-architect
      mcp: [magic]
      deliverables:
        - /kiosk/today & /kiosk/week views
        - PIN-protected exit
        - Auto-refresh every 5 min
        - Large touch targets

  - i18n_rtl:
      agent: frontend-architect
      mcp: [morphllm]
      deliverables:
        - i18n JSON files (nl/en/de/fr/tr/pl/ar)
        - RTL layout support (ar)
        - Per-user language settings
        - ICU MessageFormat

  - push_notifications:
      agent: backend-architect, frontend-architect
      mcp: [context7]
      deliverables:
        - FCM/APNs setup
        - DeviceToken registration
        - Notification triggers (due, overdue, approval)
        - Local notifications (offline)

  - advanced_gamification:
      agent: frontend-architect
      mcp: [magic, sequential]
      deliverables:
        - Streak system (daily/weekly)
        - Team quests (family goals)
        - Leaderboard (opt-in, privacy-aware)
        - Season themes (unlock via challenges)
```

### **Phase 5: Polish & Launch Prep (Weeks 15-16)**

```yaml
priority: MEDIUM
tasks:
  - security_audit:
      agent: security-engineer
      mcp: [sequential, playwright]
      deliverables:
        - OWASP MASVS checklist
        - Penetration testing
        - Audit log verification
        - AVG/COPPA compliance review

  - performance_optimization:
      agent: performance-engineer
      mcp: [sequential, playwright]
      deliverables:
        - Load testing (1000 users)
        - Mobile jank detection
        - API response time <200ms (p95)
        - Database query optimization

  - e2e_testing:
      agent: quality-engineer
      mcp: [playwright]
      deliverables:
        - Critical user flows (10+ scenarios)
        - Cross-browser testing (Web)
        - iOS/Android device testing

  - documentation:
      agent: technical-writer
      mcp: [context7]
      deliverables:
        - API documentation (OpenAPI)
        - User guides (per role)
        - Developer README
        - Deployment runbook

  - beta_launch:
      deliverables:
        - TestFlight (iOS)
        - Google Play Beta (Android)
        - Firebase Hosting (Web)
        - Onboarding tutorial
        - Feedback collection (in-app + survey)
```

---

## 🎯 Key Implementation Guidelines

### Database Migrations (Alembic)

```bash
# Rule: Create migration per feature patch
alembic revision --autogenerate -m "add_study_items_table"
alembic upgrade head

# Testing: Always test migrations on dev DB first
alembic downgrade -1
alembic upgrade head
```

### API Development Standards

```python
# Patterns to follow:
# 1. Use Pydantic schemas for validation
# 2. Dependency injection for DB sessions (core/deps.py)
# 3. RBAC checks via @require_role("parent") decorator
# 4. Consistent error responses (JSONResponse)

# Example:
@router.post("/tasks", response_model=TaskOut)
async def create_task(
    task: TaskCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_role("parent"))
):
    # Validation
    if task.due and task.due < datetime.now():
        raise HTTPException(400, "Due date cannot be in the past")

    # Business logic
    new_task = Task(id=uuid4(), familyId=current_user.familyId, ...)
    db.add(new_task)
    db.commit()

    # Audit log
    log_audit(db, current_user.id, "task_created", {"taskId": new_task.id})

    return new_task
```

### Flutter Code Organization

```dart
// Feature-based structure:
lib/
  features/
    auth/
      login_screen.dart
      register_screen.dart
      auth_provider.dart (Riverpod)
    tasks/
      task_list_screen.dart
      task_detail_screen.dart
      task_provider.dart
    gamification/
      shop_screen.dart
      badge_list_screen.dart
  api/
    client.dart
    endpoints.dart
  models/
    task.dart
    user.dart
  widgets/
    custom_button.dart
    task_card.dart
```

### AI Service Error Handling

```python
# Pattern: Graceful degradation + fallback
async def ai_plan_tasks(family_id: str, context: dict):
    try:
        response = await openrouter_client.chat_completion(
            model="anthropic/claude-3.5-sonnet",
            messages=[...],
            timeout=30
        )
        return parse_plan(response)
    except OpenRouterTimeout:
        # Fallback to simpler model
        response = await openrouter_client.chat_completion(
            model="anthropic/claude-3-haiku",
            messages=[...simplified...],
            timeout=15
        )
        return parse_plan(response)
    except Exception as e:
        # Fallback to rule-based planner
        logger.error(f"AI planner failed: {e}")
        return rule_based_planner(family_id, context)
```

---

## 🔍 Quality Gates & Success Criteria

### Definition of Done (DoD)

```yaml
feature_complete:
  - code_written: true
  - unit_tests: coverage ≥ 80%
  - integration_tests: critical_paths_covered
  - code_review: approved_by_peer
  - documentation: updated (API docs, README)
  - security_check: no_critical_vulnerabilities
  - performance_check: no_regression
  - accessibility: WCAG_AA_compliant (Web)
  - deployed_to: staging_environment

release_ready:
  - all_features: definition_of_done_met
  - e2e_tests: 100% passing
  - load_tests: meets_SLO (p95 < 200ms)
  - security_audit: passed
  - beta_feedback: addressed
  - app_store_assets: prepared (screenshots, descriptions)
  - privacy_policy: reviewed_by_legal
```

### Key Performance Indicators (KPIs)

```yaml
technical_kpis:
  - api_latency_p95: < 200ms
  - app_crash_rate: < 0.1%
  - test_coverage: ≥ 80%
  - build_success_rate: ≥ 95%

business_kpis:
  - dau_mau_ratio: ≥ 0.55 (daily active users / monthly active users)
  - task_completion_rate: ≥ 75% (on-time)
  - churn_rate: < 2% per month
  - nps_score: ≥ +45 (net promoter score)
  - premium_conversion: ≥ 4%

user_experience_kpis:
  - onboarding_completion: ≥ 80%
  - feature_adoption_calendar: ≥ 70%
  - feature_adoption_gamification: ≥ 60%
  - support_ticket_rate: < 5% of users
```

---

## 🚨 Risk Management

### Identified Risks & Mitigations

```yaml
risk_ai_latency:
  probability: medium
  impact: high
  mitigation:
    - Cache AI responses (1 hour TTL)
    - Progressive UI (loading states)
    - Model fallback (Sonnet → Haiku → rule-based)
    - Async processing (queue heavy AI tasks)

risk_privacy_children:
  probability: low
  impact: critical
  mitigation:
    - PII minimization (collect only necessary data)
    - Parental consent required (<13 years)
    - No ads in child views
    - Data encryption (at-rest + in-transit)
    - Regular privacy audits

risk_abuse_points:
  probability: medium
  impact: medium
  mitigation:
    - Photo required (heuristic trigger)
    - Rate limiting (30s between completions)
    - Parent approval flag (suspicious patterns)
    - Audit logging (all point transactions)

risk_overscheduling:
  probability: low
  impact: medium
  mitigation:
    - AI load balancer (max 3 tasks/day per child)
    - Parent override (manual adjustments)
    - Capacity warnings (UI alerts)

risk_sync_conflicts:
  probability: high
  impact: medium
  mitigation:
    - Conflict resolution rules (done > open)
    - Optimistic locking (version field)
    - User-friendly conflict UI (manual resolution option)
```

---

## 📚 Documentation Standards

### Code Comments

```python
# Backend (Python):
# - Module docstrings: Purpose, dependencies, usage examples
# - Function docstrings: Google style (Args, Returns, Raises)
# - Inline comments: Only for non-obvious logic

def calculate_fairness_score(user: User, tasks: List[Task]) -> float:
    """
    Calculate fairness score based on workload distribution.

    Args:
        user: User object with age and role
        tasks: List of tasks assigned to user this week

    Returns:
        Float between 0.0 (underloaded) and 1.0 (overloaded)

    Raises:
        ValueError: If user age is invalid
    """
    pass
```

```dart
// Flutter (Dart):
// - Class docstrings: Purpose and usage
// - Method docstrings: Parameters, return value
// - TODOs: Only for tracked issues (link to GitHub issue)

/// Task list screen showing all family tasks.
///
/// Filters tasks based on user role:
/// - Parents see all tasks
/// - Children see only assigned tasks
class TaskListScreen extends ConsumerWidget {
  /// Creates a task list screen.
  const TaskListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // ...
  }
}
```

### Git Commit Messages

```bash
# Format: <type>(<scope>): <subject>
# Types: feat, fix, docs, style, refactor, test, chore

feat(tasks): add photo upload for task completion
fix(auth): resolve 2FA token expiry issue
docs(readme): update deployment instructions
refactor(gamification): extract badge logic to service
test(sync): add conflict resolution test cases
```

---

## 🎓 Developer Onboarding Checklist

```yaml
environment_setup:
  - install_python_3.11
  - install_flutter_3.x
  - install_postgresql_15
  - install_redis_7
  - clone_repository
  - setup_venv: python -m venv .venv
  - install_dependencies: pip install -r requirements.txt && flutter pub get
  - configure_env: cp .env.example .env (fill in API keys)
  - run_migrations: alembic upgrade head
  - seed_data: python scripts/seed_dev_data.py

first_run:
  - start_backend: uvicorn main:app --reload
  - start_flutter_web: flutter run -d chrome
  - test_login: Use dev account (test@famquest.com / password123)
  - explore_features: Calendar → Tasks → Shop

development_workflow:
  - create_feature_branch: git checkout -b feat/your-feature
  - write_code: Follow patterns in existing modules
  - write_tests: Unit + integration tests
  - run_tests: pytest && flutter test
  - commit: Use conventional commit messages
  - push_pr: GitHub PR with description
  - request_review: Tag @team-member
  - merge_after_approval: Squash and merge
```

---

## 🔗 External Dependencies & API Keys

### Required Environment Variables

```bash
# Backend (.env)
DATABASE_URL=postgresql://user:pass@localhost:5432/famquest
REDIS_URL=redis://localhost:6379
SECRET_KEY=your-secret-key-here # JWT signing

OPENROUTER_API_KEY=sk-or-v1-... # AI services
OPENROUTER_BASE_URL=https://openrouter.ai/api/v1

# SSO
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
FCM_SERVER_KEY=... # Firebase Cloud Messaging
APNS_KEY_PATH=./apns_key.p8
APNS_KEY_ID=...
APNS_TEAM_ID=...

# Storage
S3_BUCKET=famquest-media
S3_ACCESS_KEY=...
S3_SECRET_KEY=...
S3_REGION=eu-west-1

# Email
SENDGRID_API_KEY=... # or MAILGUN_API_KEY
EMAIL_FROM=noreply@famquest.app

# Monitoring
SENTRY_DSN=https://...@sentry.io/...
```

### Flutter Configuration

```dart
// lib/config.dart
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

---

## 🛡️ Security Hardening Checklist

```yaml
authentication:
  - jwt_expiry: 15min (access), 7days (refresh)
  - password_hashing: bcrypt (cost factor 12)
  - 2fa_enforcement: optional (recommended for parents)
  - session_invalidation: on_logout + on_password_change

authorization:
  - rbac_enforcement: all_endpoints (no bypass)
  - child_restrictions: photo_upload_blocked, api_rate_limited
  - helper_isolation: no_family_data_access

data_protection:
  - tls_version: 1.2+ only
  - cors_policy: whitelist_origins_only
  - input_validation: pydantic_schemas + sqlalchemy_parameterized
  - output_sanitization: xss_prevention (html_escape)
  - sql_injection_prevention: orm_only (no raw queries)

privacy:
  - pii_anonymization: before_ai_requests
  - data_retention: 2years (configurable), auto_delete_after
  - gdpr_compliance: export_data, delete_account
  - audit_logging: all_sensitive_actions

infrastructure:
  - firewall: vpc_rules (backend not public)
  - secrets_management: aws_secrets_manager / vault
  - backup_strategy: daily_postgres_snapshots, 30day_retention
  - disaster_recovery: rto_4h, rpo_1h
```

---

## 📞 Support & Maintenance

### Monitoring & Alerting

```yaml
error_tracking:
  tool: Sentry
  alerts:
    - error_rate_spike: >10 errors/min
    - critical_exception: immediate_slack_notification

performance_monitoring:
  tool: Prometheus + Grafana
  metrics:
    - api_latency_p95
    - db_connection_pool_usage
    - celery_queue_length
  alerts:
    - latency_p95: >500ms
    - db_pool_exhaustion: >80%

uptime_monitoring:
  tool: UptimeRobot / Pingdom
  checks: [api_health, web_health, db_connection]
  alerts: slack_channel + pagerduty
```

### Support Channels

```yaml
users:
  - email: support@famquest.app
  - in_app_help: FAQ + contact_form
  - knowledge_base: help.famquest.app

developers:
  - github_issues: Bug reports, feature requests
  - slack_workspace: Internal team communication
  - documentation: docs.famquest.app (internal)
```

---

## 🎉 Success Metrics (Post-Launch)

### 3-Month Goals

```yaml
adoption:
  - registered_families: 500+
  - dau: 200+
  - family_unlock_purchases: 50 (10%)
  - premium_subscribers: 20 (4%)

engagement:
  - tasks_completed_per_week: 2000+
  - avg_session_duration: 5min+
  - retention_week_4: 60%+

satisfaction:
  - app_store_rating: ≥4.5 stars
  - nps_score: ≥+40
  - support_ticket_resolution_time: <24h
```

### 12-Month Goals

```yaml
scale:
  - registered_families: 5000+
  - dau_mau_ratio: ≥0.55
  - churn_rate: <2% per month

revenue:
  - family_unlock_conversion: 20%
  - premium_conversion: 4%
  - mrr: €5000+

product:
  - feature_completion: 95% of PRD
  - nps_score: ≥+45
  - app_store_rating: ≥4.7 stars
```

---

## 🔄 Continuous Improvement

### Feedback Loops

```yaml
user_feedback:
  - in_app_surveys: quarterly_nps + feature_satisfaction
  - user_interviews: 10_families_per_quarter
  - beta_program: early_access_to_features

analytics:
  - mixpanel: event_tracking (task_completed, points_earned, etc.)
  - hotjar: heatmaps + session_recordings (web)
  - crashlytics: crash_reports + jank_detection

iteration_cycle:
  - sprint_length: 2_weeks
  - retrospectives: end_of_sprint
  - roadmap_review: monthly (adjust priorities)
```

### Version Naming

```yaml
pattern: MAJOR.MINOR.PATCH
examples:
  - 1.0.0: Initial public release
  - 1.1.0: New feature (e.g., team quests)
  - 1.1.1: Bug fix (e.g., sync conflict resolution)
  - 2.0.0: Breaking change (e.g., API v2)
```

---

## 🙏 Acknowledgments & Resources

### Key Resources

```yaml
documentation:
  - flutter: https://docs.flutter.dev
  - fastapi: https://fastapi.tiangolo.com
  - openrouter: https://openrouter.ai/docs
  - sqlalchemy: https://docs.sqlalchemy.org

community:
  - flutter_discord: https://discord.gg/flutter
  - fastapi_gitter: https://gitter.im/tiangolo/fastapi
  - stackoverflow: Tag with [flutter], [fastapi], [famquest]
```

---

## 📝 Changelog Template

```markdown
# Changelog

## [Unreleased]
### Added
- Voice commands (NL/EN/DE/FR support)
- Team quests (family-wide challenges)

### Changed
- Improved offline sync performance (delta-sync algorithm)

### Fixed
- Task completion notification not sent to parent

## [1.0.0] - 2025-11-XX
### Added
- Initial release with calendar, tasks, gamification
- SSO (Google, Apple, Microsoft, Facebook)
- AI task planner
- Vision cleaning tips
- Homework coach
```

---

## 🎯 TL;DR: Quick Start Commands

```bash
# Backend
cd backend
python -m venv .venv && source .venv/bin/activate  # Windows: .venv\Scripts\activate
pip install -r requirements.txt
cp .env.example .env  # Fill in API keys
alembic upgrade head
uvicorn main:app --reload  # http://localhost:8000

# Flutter (Web)
cd flutter_app
flutter pub get
flutter run -d chrome  # http://localhost:54321

# Flutter (Mobile)
flutter run -d ios  # or 'android'

# Tests
pytest  # Backend
flutter test  # Flutter
```

---

**End of CLAUDE.md v2.1**

> **Next Steps**: Proceed with Phase 1 implementation using agent orchestration patterns defined above.
> **Agent Activation**: Use `/sc:implement [feature]` with appropriate MCP tools per task matrix.
> **Feedback**: Update this document as architecture evolves and new patterns emerge.

**SuperClaude Framework**: Activated with agent coordination and MCP integration for optimal development velocity.
