# Database Migration & Testing Guide

**FamQuest MVP - Complete Schema Migration**

This guide walks through testing and deploying the complete 16-table database schema.

---

## Prerequisites

### 1. Install Python Dependencies

```bash
cd backend
pip install -r requirements.txt
pip install psycopg2-binary  # PostgreSQL adapter
```

**Required packages:**
- SQLAlchemy 2.0.36
- Alembic 1.13.2
- psycopg2-binary

### 2. Database Setup

**Option A: Local PostgreSQL**
```bash
# Install PostgreSQL 15+
# Create database
createdb famquest

# Set environment variable
export DATABASE_URL="postgresql://postgres:postgres@localhost:5432/famquest"
```

**Option B: Docker PostgreSQL**
```bash
docker run --name famquest-db \
  -e POSTGRES_PASSWORD=postgres \
  -e POSTGRES_DB=famquest \
  -p 5432:5432 \
  -d postgres:15-alpine

export DATABASE_URL="postgresql://postgres:postgres@localhost:5432/famquest"
```

---

## Migration Steps

### Step 1: Verify Models Import

Test that all models load correctly:

```bash
cd backend
python -c "from core.models import *; print('✓ All models imported successfully')"
```

**Expected output:**
```
✓ All models imported successfully
```

**If errors occur:**
- Check that all foreign key references are correct
- Verify JSONB/ARRAY imports from `sqlalchemy.dialects.postgresql`

### Step 2: Run Migration

Apply the migration to create all tables:

```bash
cd backend
alembic upgrade head
```

**Expected output:**
```
INFO  [alembic.runtime.migration] Context impl PostgresqlImpl.
INFO  [alembic.runtime.migration] Will assume transactional DDL.
INFO  [alembic.runtime.migration] Running upgrade  -> 0001_initial, Initial schema
INFO  [alembic.runtime.migration] Running upgrade 0001_initial -> 0002_complete_mvp_schema, Complete MVP schema
```

### Step 3: Verify Tables Created

Check that all 16 tables were created:

```bash
psql $DATABASE_URL -c "\dt"
```

**Expected tables:**
```
 Schema |       Name        | Type  |  Owner
--------+-------------------+-------+----------
 public | alembic_version   | table | postgres
 public | audit_log         | table | postgres
 public | badges            | table | postgres
 public | device_tokens     | table | postgres
 public | events            | table | postgres
 public | families          | table | postgres
 public | media             | table | postgres
 public | notifications     | table | postgres
 public | points_ledger     | table | postgres
 public | rewards           | table | postgres
 public | study_items       | table | postgres
 public | study_sessions    | table | postgres
 public | task_logs         | table | postgres
 public | tasks             | table | postgres
 public | user_streaks      | table | postgres
 public | users             | table | postgres
 public | webpush_subs      | table | postgres
(17 rows)
```

### Step 4: Verify Indexes

Check that all indexes were created:

```bash
psql $DATABASE_URL -c "SELECT tablename, indexname FROM pg_indexes WHERE schemaname = 'public' ORDER BY tablename, indexname;"
```

**Expected indexes (partial list):**
- `idx_task_family_status`
- `idx_task_family_due`
- `idx_task_claimable`
- `idx_event_family_start`
- `idx_event_family_category`
- `idx_user_family_role`
- `idx_user_email_verified`
- `idx_points_user_created`
- `idx_badge_user_code`
- `idx_media_family_context`
- `idx_notification_user_status`
- `idx_audit_family_created`

### Step 5: Populate Development Data

Run the seed script to create realistic test data:

```bash
cd backend
python scripts/seed_dev_data.py
```

**Expected output:**
```
============================================================
FamQuest Development Data Seeder
============================================================

Creating families...
  ✓ Created 2 families
Creating users...
  ✓ Created 9 users
Creating tasks...
  ✓ Created 7 tasks
Creating events...
  ✓ Created 4 events
Creating points and badges...
  ✓ Created 8 points entries and 2 badges
Creating streaks...
  ✓ Created 3 streaks
Creating rewards...
  ✓ Created 4 rewards
Creating study items...
  ✓ Created 2 study items and 1 sessions
Creating audit logs...
  ✓ Created 3 audit logs

============================================================
✓ Seeding completed successfully!
============================================================

Test accounts:
  Parent (Eva): eva@famquest.dev / famquest123
  Parent (Mark): mark@famquest.dev / famquest123
  Teen (Sam): sam@famquest.dev / famquest123
  Child (Noah): PIN 1234
  Child (Luna): PIN 5678
  Helper (Mira): mira@famquest.dev / famquest123

============================================================
```

### Step 6: Verify Seed Data

Query the database to confirm data was inserted:

```sql
-- Count records in each table
SELECT 'families' AS table_name, COUNT(*) FROM families
UNION ALL
SELECT 'users', COUNT(*) FROM users
UNION ALL
SELECT 'tasks', COUNT(*) FROM tasks
UNION ALL
SELECT 'events', COUNT(*) FROM events
UNION ALL
SELECT 'points_ledger', COUNT(*) FROM points_ledger
UNION ALL
SELECT 'badges', COUNT(*) FROM badges
UNION ALL
SELECT 'user_streaks', COUNT(*) FROM user_streaks
UNION ALL
SELECT 'rewards', COUNT(*) FROM rewards
UNION ALL
SELECT 'study_items', COUNT(*) FROM study_items
UNION ALL
SELECT 'study_sessions', COUNT(*) FROM study_sessions;
```

**Expected counts:**
```
   table_name   | count
----------------+-------
 families       |     2
 users          |     9
 tasks          |     7
 events         |     4
 points_ledger  |     8
 badges         |     2
 user_streaks   |     3
 rewards        |     4
 study_items    |     2
 study_sessions |     1
```

---

## Testing Queries

### 1. Get Family Tasks

```sql
SELECT t.title, t.status, t.due, t.points
FROM tasks t
JOIN families f ON t.familyId = f.id
WHERE f.name = 'Gezin van Eva'
ORDER BY t.due;
```

### 2. Calculate User Points Balance

```sql
SELECT u.displayName, COALESCE(SUM(pl.delta), 0) AS total_points
FROM users u
LEFT JOIN points_ledger pl ON u.id = pl.userId
WHERE u.familyId = (SELECT id FROM families WHERE name = 'Gezin van Eva')
GROUP BY u.id, u.displayName
ORDER BY total_points DESC;
```

**Expected output:**
```
 displayname | total_points
-------------+--------------
 Sam         |           84
 Noah        |           10
 Tom         |           10
 Eva         |            0
 Mark        |            0
 Luna        |            0
 Mira        |            0
```

### 3. Get User Streaks

```sql
SELECT u.displayName, us.currentStreak, us.longestStreak
FROM users u
LEFT JOIN user_streaks us ON u.id = us.userId
WHERE u.familyId = (SELECT id FROM families WHERE name = 'Gezin van Eva')
ORDER BY us.currentStreak DESC NULLS LAST;
```

### 4. Get Upcoming Events

```sql
SELECT e.title, e.start, e.category
FROM events e
JOIN families f ON e.familyId = f.id
WHERE f.name = 'Gezin van Eva'
  AND e.start > NOW()
ORDER BY e.start
LIMIT 5;
```

### 5. Get Claimable Tasks

```sql
SELECT t.title, t.points, t.estDuration
FROM tasks t
JOIN families f ON t.familyId = f.id
WHERE f.name = 'Gezin van Eva'
  AND t.claimable = true
  AND t.status = 'open';
```

---

## Rollback Procedure

If you need to rollback the migration:

```bash
# Rollback to previous version
alembic downgrade -1

# Verify current version
alembic current

# Expected output:
# 0001_initial (head)
```

**Warning:** Rollback will **delete all data** in the 7 new tables:
- events
- task_logs
- user_streaks
- study_items
- study_sessions
- media
- notifications

---

## Performance Testing

### 1. Query Performance

Test hot query paths:

```sql
-- Test: Get family tasks (should be < 10ms with index)
EXPLAIN ANALYZE
SELECT * FROM tasks
WHERE familyId = (SELECT id FROM families LIMIT 1)
  AND status = 'open';

-- Test: Calculate user points (should be < 5ms with index)
EXPLAIN ANALYZE
SELECT SUM(delta) FROM points_ledger
WHERE userId = (SELECT id FROM users LIMIT 1);

-- Test: Get calendar events for range (should be < 15ms with index)
EXPLAIN ANALYZE
SELECT * FROM events
WHERE familyId = (SELECT id FROM families LIMIT 1)
  AND start BETWEEN NOW() AND NOW() + INTERVAL '30 days';
```

**Performance targets:**
- Family task list: < 10ms
- User points calculation: < 5ms
- Calendar range query: < 15ms

### 2. Index Usage

Verify indexes are being used:

```sql
-- Check if indexes are used
EXPLAIN (FORMAT JSON)
SELECT * FROM tasks
WHERE familyId = 'some_id' AND status = 'open';

-- Look for "Index Scan" in the output
```

---

## Common Issues & Solutions

### Issue 1: Module not found errors

**Error:**
```
ModuleNotFoundError: No module named 'sqlalchemy'
```

**Solution:**
```bash
pip install -r requirements.txt
pip install psycopg2-binary
```

### Issue 2: Database connection refused

**Error:**
```
psycopg2.OperationalError: could not connect to server
```

**Solution:**
```bash
# Check PostgreSQL is running
pg_isready

# Check DATABASE_URL is set
echo $DATABASE_URL

# Test connection
psql $DATABASE_URL -c "SELECT 1;"
```

### Issue 3: Migration fails with "column already exists"

**Error:**
```
sqlalchemy.exc.ProgrammingError: (psycopg2.errors.DuplicateColumn) column "emailVerified" already exists
```

**Solution:**
```bash
# Check current migration version
alembic current

# If stuck, manually fix database or drop and recreate
dropdb famquest && createdb famquest
alembic upgrade head
```

### Issue 4: Foreign key violation during seed

**Error:**
```
psycopg2.errors.ForeignKeyViolation: insert or update on table "tasks" violates foreign key constraint "tasks_familyId_fkey"
```

**Solution:**
- Ensure families are created before users/tasks
- Check that foreign key IDs exist in referenced tables
- Verify seed script order (families → users → tasks)

---

## Next Steps

After successful migration:

1. **Update API Endpoints**: Modify backend routes to use new schema
2. **Test Existing Endpoints**: Ensure backward compatibility with old API
3. **Update Frontend Models**: Add new fields to Flutter models
4. **Test E2E Flows**: Verify task creation, completion, points awarding
5. **Performance Monitoring**: Set up query monitoring and alerts

---

## Deployment Checklist

Before deploying to staging/production:

- [ ] Backup existing database
- [ ] Test migration on staging environment
- [ ] Verify all indexes created successfully
- [ ] Test query performance (p95 < 200ms)
- [ ] Run seed script to verify data integrity
- [ ] Test rollback procedure
- [ ] Update API documentation
- [ ] Update frontend models
- [ ] Run E2E tests
- [ ] Schedule maintenance window

---

## Additional Resources

- **Schema Documentation**: `backend/docs/database_schema.md`
- **Migration File**: `backend/alembic/versions/0002_complete_mvp_schema.py`
- **Models**: `backend/core/models.py`
- **Seed Script**: `backend/scripts/seed_dev_data.py`

---

**End of Migration Guide**
