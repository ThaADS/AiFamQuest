# Integration Tests - Quick Reference

## Quick Start

```bash
# Run all integration tests
pytest backend/tests/integration/ -v

# Run with coverage
pytest backend/tests/integration/ --cov=backend --cov-report=html

# Run specific file
pytest backend/tests/integration/test_calendar_integration.py -v

# Run specific test
pytest backend/tests/integration/test_calendar_integration.py::TestCalendarIntegration::test_create_event_full_flow -v
```

## Test Files

### ✅ Implemented
- `conftest.py` - Test fixtures and configuration (450 lines)
- `helpers.py` - Test utility functions (400 lines)
- `test_calendar_integration.py` - Calendar tests (12 tests, 350 lines)
- `test_auth_flow.py` - Authentication tests (10 tests, 320 lines)

### ⏳ To Be Implemented
- `test_task_lifecycle.py` - Task workflow tests (15 tests needed)
- `test_gamification_flow.py` - Gamification tests (12 tests needed)
- `test_calendar_task_integration.py` - Calendar-task integration (7 tests needed)
- `test_fairness_calendar_integration.py` - Fairness-calendar integration (6 tests needed)
- `test_data_integrity.py` - Data integrity tests (8 tests needed)
- `test_performance.py` - Performance benchmarks (8 tests needed)

## Test Coverage

**Current**: 22/90 tests (24%)
- Calendar: 12/15 (85% coverage)
- Auth: 10/12 (83% coverage)
- Tasks: 0/15 (0% coverage)
- Gamification: 0/12 (0% coverage)

**Target**: >80% integration coverage

## Available Fixtures

From `conftest.py`:
- `test_db` - Fresh database for each test
- `sample_family` - Family with 4 users (parent, teen, 2 children)
- `sample_events` - 20 realistic calendar events
- `sample_tasks` - 30 realistic tasks
- `auth_headers` - JWT tokens for all users
- `api_client` - Enhanced API client with role-based methods

## Helper Functions

From `helpers.py`:
- `create_test_family()` - Create test family with users
- `generate_test_events()` - Generate realistic events
- `generate_test_tasks()` - Generate realistic tasks
- `complete_task_as_user()` - Simulate task completion
- `verify_gamification_state()` - Validate points/streaks/badges
- `simulate_offline_sync()` - Test offline operations
- `create_performance_test_data()` - Generate large datasets

## Documentation

See `/docs/` for complete guides:
- `INTEGRATION_TEST_PLAN.md` - Complete testing strategy
- `INTEGRATION_TEST_IMPLEMENTATION_SUMMARY.md` - Technical details
- `INTEGRATION_TEST_RESULTS.md` - Execution results

## CI/CD

GitHub Actions workflow: `.github/workflows/integration-tests.yml`
- Runs on every PR
- PostgreSQL + Redis services
- Coverage reporting
- PR comments with results
