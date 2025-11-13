# FamQuest Phase 2 — Integration Test Plan

**Version**: 1.0
**Date**: 2025-11-11
**Status**: In Progress
**Coverage Target**: >80% for integration scenarios

---

## Overview

This document outlines the comprehensive integration testing strategy for FamQuest Phase 2, covering all major components and their interactions.

## Test Strategy

### Objectives
1. Validate end-to-end user workflows across all Phase 2 features
2. Verify data consistency across components (calendar, tasks, auth, gamification)
3. Ensure offline-first architecture works correctly
4. Validate performance benchmarks are met
5. Test cross-component integration points

### Scope

**In Scope**:
- Backend API integration tests
- Cross-component data flow
- Authentication and authorization flows
- Gamification calculations
- Calendar and task interactions
- Data integrity and consistency
- Performance benchmarks
- Offline sync scenarios

**Out of Scope**:
- Unit tests (covered separately)
- UI-only tests (covered in Flutter tests)
- Infrastructure tests
- Third-party service tests (mocked)

---

## Test Categories

### 1. Calendar Integration Tests
**File**: `backend/tests/integration/test_calendar_integration.py`

| Test Case | Description | Priority | Status |
|-----------|-------------|----------|--------|
| Create event full flow | Create → Store → Retrieve → Verify | HIGH | ✅ Complete |
| Recurring event expansion | RRULE → Expand → Validate dates | HIGH | ✅ Complete |
| Update event notification | Update → Notify attendees → Verify | MEDIUM | ✅ Complete |
| Delete recurring event | Delete → Remove all occurrences | HIGH | ✅ Complete |
| Offline event sync | Offline create → Sync → No duplicates | HIGH | ✅ Complete |
| Access control by role | Role-based event visibility | MEDIUM | ✅ Complete |
| Week/Month view performance | Response <500ms with 100 events | HIGH | ✅ Complete |
| All-day event handling | Create/retrieve all-day events | LOW | ✅ Complete |

**Coverage**: 12 test cases, ~85% of calendar workflows

### 2. Authentication Flow Tests
**File**: `backend/tests/integration/test_auth_flow.py`

| Test Case | Description | Priority | Status |
|-----------|-------------|----------|--------|
| Email/password login | Login → JWT → Access endpoint | HIGH | ✅ Complete |
| Apple SSO flow | SSO → Create user → Login | HIGH | ✅ Complete |
| 2FA setup complete | Setup → QR → Verify → Login | HIGH | ✅ Complete |
| Backup code single-use | Use backup code → Verify removed | HIGH | ✅ Complete |
| Rate limiting | Failed attempts → Lock account | MEDIUM | ✅ Complete |
| 2FA disable | Disable 2FA → Verify | MEDIUM | ✅ Complete |
| Password reset | Request → Token → Reset | MEDIUM | ✅ Complete |
| Session expiration | Token expires → Refresh → Access | MEDIUM | ✅ Complete |

**Coverage**: 10 test cases, ~90% of auth workflows

### 3. Task Lifecycle Tests
**File**: `backend/tests/integration/test_task_lifecycle.py`
**Status**: TO BE IMPLEMENTED

| Test Case | Description | Priority | Status |
|-----------|-------------|----------|--------|
| Create recurring task | RRULE → Auto-rotation → Assignment | HIGH | ⏳ Pending |
| Complete task flow | Complete → Points → Streak → Badge | HIGH | ⏳ Pending |
| Parent approval | Submit → Approve/Reject → Points | HIGH | ⏳ Pending |
| Task with photo | Upload → AV scan → Display | MEDIUM | ⏳ Pending |
| Recurring rotation | Next occurrence → Rotate assignee | HIGH | ⏳ Pending |
| Claimable task | List → Claim → Complete | MEDIUM | ⏳ Pending |
| Task fairness assignment | Workload balance → Fair rotation | HIGH | ⏳ Pending |

**Recommended Tests**: 15+ test cases covering CRUD, recurrence, rotation, approval

### 4. Gamification Flow Tests
**File**: `backend/tests/integration/test_gamification_flow.py`
**Status**: TO BE IMPLEMENTED

| Test Case | Description | Priority | Status |
|-----------|-------------|----------|--------|
| Complete task points | Complete → Calculate multipliers → Award | HIGH | ⏳ Pending |
| Streak tracking | Complete daily → Update streak → Reset on miss | HIGH | ⏳ Pending |
| Badge unlocking | Meet condition → Award badge → Notification | HIGH | ⏳ Pending |
| Reward redemption | Redeem → Deduct points → Update balance | MEDIUM | ⏳ Pending |
| Leaderboard ranking | Complete tasks → Update leaderboard → Cache | MEDIUM | ⏳ Pending |
| Points calculation | Task + multipliers → Correct total | HIGH | ⏳ Pending |
| Streak broken | Miss day → Reset streak → Notification | MEDIUM | ⏳ Pending |

**Recommended Tests**: 12+ test cases covering points, streaks, badges, rewards

### 5. Cross-Component Integration Tests
**Files**:
- `backend/tests/integration/test_calendar_task_integration.py`
- `backend/tests/integration/test_fairness_calendar_integration.py`

**Status**: TO BE IMPLEMENTED

| Test Case | Description | Priority | Status |
|-----------|-------------|----------|--------|
| Task due + calendar conflict | Check calendar → Suggest alternative | HIGH | ⏳ Pending |
| Recurring event task blocking | Event → Block task time → Show busy | MEDIUM | ⏳ Pending |
| Calendar event task generation | Event ends → Auto-create cleanup task | LOW | ⏳ Pending |
| Family event task respect | All attendees → Respect busy times | MEDIUM | ⏳ Pending |
| Fairness + calendar workload | Include busy hours → Reduce capacity | HIGH | ⏳ Pending |
| Fairness skip conflicts | User busy → Skip in rotation | HIGH | ⏳ Pending |
| Weekly gen + vacation | Respect vacation events → Skip tasks | MEDIUM | ⏳ Pending |

**Recommended Tests**: 10+ test cases covering interactions

### 6. Data Integrity Tests
**File**: `backend/tests/integration/test_data_integrity.py`
**Status**: TO BE IMPLEMENTED

| Test Case | Description | Priority | Status |
|-----------|-------------|----------|--------|
| Optimistic locking | Concurrent updates → Conflict detection | HIGH | ⏳ Pending |
| Cascade deletes | Delete family → Remove all data | HIGH | ⏳ Pending |
| Foreign key constraints | Orphaned records → Prevent/cleanup | HIGH | ⏳ Pending |
| Transaction rollback | Partial failure → Rollback all | HIGH | ⏳ Pending |
| Audit log completeness | All mutations → Logged | MEDIUM | ⏳ Pending |

**Recommended Tests**: 8+ test cases covering data consistency

### 7. Performance Integration Tests
**File**: `backend/tests/integration/test_performance.py`
**Status**: TO BE IMPLEMENTED

| Test Case | Benchmark | Priority | Status |
|-----------|-----------|----------|--------|
| Calendar month view | <500ms with 100 events | HIGH | ⏳ Pending |
| Task list filtered | <200ms with 1000 tasks | HIGH | ⏳ Pending |
| Gamification stats | <300ms complex calculations | MEDIUM | ⏳ Pending |
| Leaderboard generation | <400ms for 50 members | MEDIUM | ⏳ Pending |
| Recurring expansion | <100ms for 365 occurrences | HIGH | ⏳ Pending |

**Recommended Tests**: 8+ performance benchmark tests

---

## Flutter Integration Tests

### Setup
**File**: `flutter_app/integration_test/app_test.dart`
**Status**: TO BE IMPLEMENTED

### Critical User Flows

#### 1. Login → Task Completion Flow
```dart
testWidgets('Complete task flow increases points and streak', (tester) async {
  // 1. Login with email/password
  // 2. Navigate to tasks screen
  // 3. Select a task
  // 4. Mark as complete
  // 5. Verify points increased
  // 6. Verify streak updated
  // 7. Check for new badges
});
```

#### 2. Calendar Event Creation Flow
```dart
testWidgets('Create recurring calendar event', (tester) async {
  // 1. Navigate to calendar
  // 2. Tap create event button
  // 3. Fill in event details
  // 4. Add attendees
  // 5. Set recurrence (weekly)
  // 6. Save event
  // 7. Verify in month view
});
```

#### 3. 2FA Setup Flow
```dart
testWidgets('Enable 2FA with QR code', (tester) async {
  // 1. Navigate to settings
  // 2. Tap Enable 2FA
  // 3. Scan QR code (simulate)
  // 4. Enter verification code
  // 5. Save backup codes
  // 6. Logout and login with 2FA
});
```

#### 4. Gamification Flow
```dart
testWidgets('View gamification stats', (tester) async {
  // 1. Navigate to leaderboard
  // 2. Check personal stats
  // 3. View badge catalog
  // 4. Navigate to locked badge
  // 5. See progress percentage
});
```

#### 5. Offline → Online Flow
```dart
testWidgets('Offline sync restores consistency', (tester) async {
  // 1. Disconnect network
  // 2. Create task offline
  // 3. Mark task complete offline
  // 4. Reconnect network
  // 5. Verify auto-sync
  // 6. Check data consistency
});
```

**Recommended Tests**: 10+ critical user flow tests

---

## Test Execution

### Prerequisites
```bash
# Backend
cd backend
python -m venv venv
source venv/bin/activate  # Windows: venv\Scripts\activate
pip install -r requirements.txt
pip install pytest pytest-cov

# Flutter
cd flutter_app
flutter pub get
```

### Running Backend Tests
```bash
# All integration tests
pytest backend/tests/integration/ -v

# Specific test file
pytest backend/tests/integration/test_calendar_integration.py -v

# With coverage
pytest backend/tests/integration/ --cov=backend --cov-report=html
```

### Running Flutter Tests
```bash
# All integration tests
flutter test integration_test/

# Specific test
flutter test integration_test/app_test.dart

# With coverage
flutter test --coverage
```

### Performance Testing
```bash
# Run performance tests
pytest backend/tests/integration/test_performance.py -v

# With profiling
pytest backend/tests/integration/test_performance.py -v --profile
```

---

## Success Criteria

### Quantitative Metrics
- ✅ 30+ backend integration tests created
- ✅ 5+ Flutter critical user flow tests
- ✅ >80% integration test coverage
- ✅ All performance benchmarks met
- ✅ Zero data integrity failures
- ✅ Complete documentation

### Qualitative Metrics
- All major user workflows tested end-to-end
- Cross-component interactions validated
- Offline sync scenarios working correctly
- Security flows (auth, 2FA) functioning properly
- Gamification calculations accurate

---

## Test Data Management

### Test Fixtures
- **Families**: 1 test family with 4 users (parent, teen, 2 children)
- **Events**: 20 realistic events (recurring, all-day, categorized)
- **Tasks**: 30 tasks (recurring, rotation strategies, various statuses)
- **Users**: Multiple roles for access control testing
- **Gamification**: Sample points, streaks, badges

### Database Strategy
- Use in-memory SQLite for speed
- Fresh database for each test
- Fixtures in `conftest.py`
- Helper functions in `helpers.py`

---

## CI/CD Integration

### GitHub Actions Workflow
**File**: `.github/workflows/integration-tests.yml`

**Triggers**:
- Every pull request
- Push to main branch
- Manual workflow dispatch

**Steps**:
1. Setup Python + PostgreSQL + Redis
2. Install dependencies
3. Run backend integration tests
4. Run Flutter integration tests (headless)
5. Generate coverage reports
6. Post results as PR comment
7. Fail PR if tests fail or coverage <80%

---

## Test Maintenance

### Adding New Tests
1. Identify workflow to test
2. Create test in appropriate file
3. Use fixtures from `conftest.py`
4. Follow naming convention: `test_<workflow>_<scenario>`
5. Document expected behavior
6. Add to this plan document

### Test Review Checklist
- [ ] Test name clearly describes scenario
- [ ] Test is isolated (no dependencies on other tests)
- [ ] Test uses fixtures (no hardcoded data)
- [ ] Test includes assertions for all critical paths
- [ ] Test handles cleanup properly
- [ ] Test documents expected behavior

---

## Known Issues and Workarounds

### Issue 1: SQLite vs PostgreSQL Differences
**Impact**: Some PostgreSQL-specific features don't work in SQLite
**Workaround**: Use PostgreSQL container for CI/CD, mock specific features in tests

### Issue 2: Async Operations in Tests
**Impact**: Some operations require waiting for background tasks
**Workaround**: Use `time.sleep()` or polling with timeout

### Issue 3: Timezone Handling
**Impact**: DateTime comparisons can fail due to timezone differences
**Workaround**: Always use UTC in tests, normalize timezones before comparison

---

## Next Steps

### Immediate (This Week)
1. ✅ Create test infrastructure (conftest.py, helpers.py)
2. ✅ Implement calendar integration tests
3. ✅ Implement auth flow tests
4. ⏳ Implement task lifecycle tests
5. ⏳ Implement gamification tests

### Short-term (Next Week)
6. ⏳ Create cross-component integration tests
7. ⏳ Create data integrity tests
8. ⏳ Create performance tests
9. ⏳ Implement Flutter integration tests
10. ⏳ Setup CI/CD workflow

### Medium-term (Next 2 Weeks)
11. Run full test suite
12. Document all results
13. Fix identified issues
14. Achieve >80% coverage
15. Integrate into development workflow

---

## Resources

### Documentation
- [Phase 2 Progress](./PHASE_2_PROGRESS.md)
- [Calendar API Docs](../backend/docs/CALENDAR_API.md)
- [Auth Security Docs](../backend/docs/auth_security.md)
- [Task Recurrence Docs](../backend/docs/TASKS_RECURRENCE.md)
- [Gamification Docs](../backend/docs/GAMIFICATION.md)

### Tools
- pytest: https://docs.pytest.org
- pytest-cov: https://pytest-cov.readthedocs.io
- Flutter integration_test: https://flutter.dev/docs/testing/integration-tests

---

**Document Owner**: Quality Engineer
**Last Updated**: 2025-11-11
**Next Review**: 2025-11-18
