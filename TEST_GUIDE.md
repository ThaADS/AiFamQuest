# FamQuest Testing Guide

**Comprehensive test suite for production readiness**

## Test Coverage Overview

### Widget Tests (70% coverage target)
- **Location**: `flutter_app/test/widgets/`
- **Count**: 50+ tests across 6 test files
- **Coverage**: Calendar, Tasks, Gamification, Study, Helper, Auth

### Integration Tests
- **Location**: `flutter_app/integration_test/`
- **Count**: 20+ complete user flow scenarios
- **Critical Paths**: Task lifecycle, Parent approval, Shop purchases, Study sessions, Helper system

### E2E Playwright Tests (Web PWA)
- **Location**: `e2e/`
- **Count**: 10+ critical journey scenarios
- **Platforms**: Desktop (Chrome/Firefox/Safari) + Mobile (iOS/Android)

---

## Running Tests

### 1. Flutter Widget Tests

```bash
cd flutter_app

# Run all widget tests
flutter test

# Run specific test file
flutter test test/widgets/calendar_test.dart

# Run with coverage
flutter test --coverage

# View coverage report (requires lcov)
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html
```

### 2. Flutter Integration Tests

```bash
cd flutter_app

# Run all integration tests
flutter test integration_test/

# Run on specific device
flutter test integration_test/user_flows_test.dart -d chrome
flutter test integration_test/user_flows_test.dart -d android
flutter test integration_test/user_flows_test.dart -d ios
```

### 3. Playwright E2E Tests (Web)

```bash
cd e2e

# Install dependencies (first time only)
npm install
npx playwright install

# Run all E2E tests
npm test

# Run in headed mode (see browser)
npm run test:headed

# Run with UI mode (interactive)
npm run test:ui

# Run specific test file
npx playwright test critical_journeys.spec.ts

# Debug mode
npm run test:debug

# View test report
npm run test:report
```

---

## Test File Structure

```
flutter_app/
├── test/
│   ├── widgets/
│   │   ├── calendar_test.dart (12 tests)
│   │   ├── tasks_test.dart (15 tests)
│   │   ├── gamification_test.dart (10 tests)
│   │   ├── study_test.dart (8 tests)
│   │   ├── helper_test.dart (7 tests)
│   │   └── auth_test.dart (8 tests)
│   ├── spaced_repetition_test.dart
│   ├── sync_test.dart
│   └── widget_test.dart
├── integration_test/
│   ├── app_test.dart
│   └── user_flows_test.dart (20+ scenarios)

e2e/
├── critical_journeys.spec.ts (10+ E2E tests)
├── package.json
├── playwright.config.ts
└── test-assets/
```

---

## Test Categories

### Widget Tests (60+ tests)

**Calendar Tests** (`calendar_test.dart`):
- ✅ Calendar day view rendering
- ✅ Navigation controls (prev/next day, today)
- ✅ Event display (all-day vs timed)
- ✅ Empty state handling
- ✅ Timeline hour grid
- ✅ FAB navigation

**Task Tests** (`tasks_test.dart`):
- ✅ Task completion screen rendering
- ✅ Photo upload requirement validation
- ✅ Parent approval workflow UI
- ✅ Points display
- ✅ Category icons
- ✅ Status badges
- ✅ Filtering
- ✅ Priority indicators

**Gamification Tests** (`gamification_test.dart`):
- ✅ Shop screen rendering
- ✅ Points balance display
- ✅ Reward cards with affordability
- ✅ Purchase confirmation dialog
- ✅ Badge unlock display
- ✅ Streak counter
- ✅ Leaderboard entries

**Study Tests** (`study_test.dart`):
- ✅ Study dashboard with subjects
- ✅ Study item cards
- ✅ Progress indicators
- ✅ Exam countdown
- ✅ Study sessions
- ✅ Quiz questions and results
- ✅ AI-generated plans

**Helper Tests** (`helper_test.dart`):
- ✅ Helper invite with QR code
- ✅ Helper join flow
- ✅ Task assignment
- ✅ Permission restrictions
- ✅ Helper management
- ✅ Role badge display

**Auth Tests** (`auth_test.dart`):
- ✅ Login form validation
- ✅ SSO button rendering
- ✅ 2FA setup and verification
- ✅ Password reset flow
- ✅ Child PIN login
- ✅ Registration form

### Integration Tests (20+ scenarios)

**Task Lifecycle**:
- User creates task → assigns → completes → earns points
- Photo requirement enforcement
- Parent approval workflow
- Rejection with feedback

**Gamification Flow**:
- Earn points → purchase reward
- Badge unlock animation
- Streak tracking over multiple days

**Calendar Operations**:
- Create event → edit → delete
- Recurring event instances

**Study/Homework Coach**:
- Create study plan with AI assistance
- Complete quiz and view results

**Helper System**:
- Parent invites helper → helper joins → receives tasks
- Permission restrictions verification

**Offline Sync**:
- Changes made offline → sync when online
- Conflict resolution

**AI Features**:
- Photo → cleaning tips
- Voice command → task creation

### E2E Playwright Tests (10+ critical journeys)

**Journey 1: User Onboarding**
- Registration → Profile setup → First task

**Journey 2: Task Lifecycle**
- Create → Assign → Complete → Approve (full flow)
- Photo requirement enforcement

**Journey 3: Gamification**
- Earn points → Buy reward → Unlock badge
- Streak system validation

**Journey 4: Calendar Operations**
- Create → Edit → Delete event
- Recurring event verification

**Journey 5: Helper System**
- Invite → Join → Task assignment → Permission checks

**Performance Tests**:
- App load time < 3 seconds
- Scroll performance with 50+ items

**Accessibility Tests**:
- ARIA labels on interactive elements
- Keyboard navigation

---

## Test Data Setup

### Demo Accounts (for E2E tests)

```sql
-- Parent account
email: parent@famquest.test
password: TestPass123!

-- Child account
email: child@famquest.test
pin: 1234

-- Helper account
email: helper@famquest.test
password: HelperPass123!
```

### Test Database Seeding

```bash
# Run seed script (to be created)
cd backend
python scripts/seed_test_data.py
```

---

## Coverage Goals

| Test Type | Target | Current |
|-----------|--------|---------|
| Widget Tests | 70% | 60+ tests |
| Integration Tests | 100% critical paths | 20+ scenarios |
| E2E Tests | 100% user journeys | 10+ journeys |

---

## Continuous Integration

### GitHub Actions Workflow

```yaml
# .github/workflows/test.yml
name: Test Suite

on: [push, pull_request]

jobs:
  flutter_tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: subosito/flutter-action@v2
      - run: flutter pub get
      - run: flutter test --coverage
      - uses: codecov/codecov-action@v3

  playwright_tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: actions/setup-node@v3
      - run: cd e2e && npm install
      - run: npx playwright install --with-deps
      - run: npm test
```

---

## Test Debugging Tips

### Widget Test Debugging
```dart
// Add debug prints
debugPrint('Current state: $state');

// Use pumpAndSettle with custom duration
await tester.pumpAndSettle(Duration(seconds: 5));

// Find widgets
print(tester.allWidgets.toList());
```

### Playwright Debugging
```bash
# Run in debug mode
npx playwright test --debug

# Pause on failure
npx playwright test --trace on

# Generate trace viewer
npx playwright show-trace trace.zip
```

---

## Known Issues & Workarounds

### Issue 1: Const Constructor Warnings
**Problem**: IDE shows "Use const constructor" warnings
**Impact**: Informational only, doesn't affect test execution
**Fix**: Run `dart fix --apply` in flutter_app directory

### Issue 2: Mock Data Setup
**Problem**: Tests need real backend for integration tests
**Workaround**: Use mock providers or in-memory database
**TODO**: Implement mock API client for testing

### Issue 3: Playwright Test Assets
**Problem**: Photo upload tests need test image files
**Solution**: Create `e2e/test-assets/` directory with sample images

---

## Next Steps

### Phase 1: ✅ Completed
- [x] Create comprehensive widget tests (60+ tests)
- [x] Write integration test scenarios (20+ flows)
- [x] Develop E2E Playwright suite (10+ journeys)
- [x] Document test infrastructure

### Phase 2: Pending
- [ ] Run all tests and fix failures
- [ ] Generate coverage report (target: 70%+)
- [ ] Set up CI/CD pipeline
- [ ] Create mock API client for testing
- [ ] Add test assets (images, demo data)

### Phase 3: Optimization
- [ ] Improve test performance (parallel execution)
- [ ] Add visual regression tests
- [ ] Implement accessibility test suite
- [ ] Create performance benchmarks

---

## Test Metrics Dashboard

After running tests, generate metrics:

```bash
# Widget test coverage
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html

# Playwright test report
cd e2e
npm test
npm run test:report

# View reports:
# - Flutter: coverage/html/index.html
# - Playwright: e2e/playwright-report/index.html
```

---

## Contact & Support

For test failures or questions:
- **Documentation**: See individual test files for detailed comments
- **CI/CD**: Check GitHub Actions workflow logs
- **Coverage**: Review HTML coverage reports

**Test Philosophy**: Write tests that catch real bugs, not just improve coverage numbers.

---

**Last Updated**: 2025-11-19
**Test Suite Version**: 1.0.0
**Status**: ✅ Comprehensive test infrastructure complete
