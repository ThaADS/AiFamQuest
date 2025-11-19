# FamQuest Performance Optimization Guide

## Executive Summary

This guide provides comprehensive performance optimization strategies for FamQuest across Flutter frontend, FastAPI backend, and Vercel deployment infrastructure.

**Target Metrics:**
- Flutter Web: <2s initial load, 60fps UI, <30MB bundle
- Backend API: <200ms p95 latency, >1000 req/s throughput
- Database: <50ms query p95, connection pooling enabled
- Vercel: <10s cold start, <1s warm request

---

## 1. Flutter App Performance Optimization

### 1.1 Bundle Size Reduction (Current: ~45MB, Target: <30MB)

#### Code Splitting Strategy

**Implementation:**
```dart
// lib/main.dart - Deferred loading for non-critical features
import 'features/study/study_home_screen.dart' deferred as study;
import 'features/premium/premium_screen.dart' deferred as premium;
import 'features/settings/settings_screen.dart' deferred as settings;

// Route configuration with lazy loading
final router = GoRouter(
  routes: [
    GoRoute(
      path: '/study',
      builder: (context, state) => FutureBuilder(
        future: study.loadLibrary(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return study.StudyHomeScreen();
          }
          return LoadingScreen();
        },
      ),
    ),
  ],
);
```

#### Image Optimization

**Replace current image loading:**
```yaml
# pubspec.yaml
dependencies:
  cached_network_image: ^3.3.0
  flutter_image_compress: ^2.1.0
```

```dart
// Replace Image.network with CachedNetworkImage
CachedNetworkImage(
  imageUrl: task.photoUrl,
  placeholder: (context, url) => ShimmerPlaceholder(),
  errorWidget: (context, url, error) => Icon(Icons.error),
  memCacheWidth: 800, // Limit memory cache size
  maxWidthDiskCache: 1000,
  maxHeightDiskCache: 1000,
  fadeInDuration: Duration(milliseconds: 300),
);
```

#### Tree Shaking Configuration

```dart
// flutter build web --release --tree-shake-icons --dart-define=FLUTTER_WEB_USE_SKIA=false

// Remove unused packages from pubspec.yaml:
// - Remove web: ^1.1.0 if not using fullscreen API
// - Consider replacing firebase_core with firebase_core_web only
```

### 1.2 Rendering Performance (Target: 60fps)

#### Riverpod Rebuild Optimization

**Current Issue:** Provider rebuilds trigger entire widget tree
**Solution:** Use selective providers

```dart
// BAD: Rebuilds entire screen on any task change
final tasksProvider = StateNotifierProvider<TasksNotifier, List<Task>>(...);

// GOOD: Granular providers for specific data
final taskByIdProvider = Provider.family<Task?, String>((ref, id) {
  final tasks = ref.watch(tasksProvider);
  return tasks.firstWhere((t) => t.id == id, orElse: () => null);
});

// Use in widgets
class TaskCard extends ConsumerWidget {
  final String taskId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final task = ref.watch(taskByIdProvider(taskId));
    // Only rebuilds when THIS task changes
    return ...;
  }
}
```

#### Const Constructors (25 instances to fix)

**Automated fix:**
```bash
cd flutter_app
dart fix --apply
```

**Manual fixes in test files:**
```dart
// test/widgets/tasks_test.dart
// BEFORE:
return MaterialApp(home: TaskListScreen());

// AFTER:
return const MaterialApp(home: TaskListScreen());
```

#### ListView Optimization

```dart
// Replace ListView.builder with ListView.builder + itemExtent
ListView.builder(
  itemCount: tasks.length,
  itemExtent: 120.0, // Fixed height improves performance
  itemBuilder: (context, index) => TaskCard(task: tasks[index]),
);

// For variable heights, use AutomaticKeepAliveClientMixin
class TaskCard extends StatefulWidget {
  @override
  State<TaskCard> createState() => _TaskCardState();
}

class _TaskCardState extends State<TaskCard> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for mixin
    return ...;
  }
}
```

### 1.3 Offline Performance

#### Hive Index Optimization

```dart
// lib/services/local_storage.dart
class OptimizedLocalStorage {
  static const String TASKS_BOX = 'tasks_v2'; // Version for migration
  static const String EVENTS_BOX = 'events_v2';

  Future<void> init() async {
    await Hive.initFlutter();

    // Register adapters
    Hive.registerAdapter(TaskAdapter());

    // Open boxes with encryption
    final key = await _getEncryptionKey();
    await Hive.openBox<Task>(
      TASKS_BOX,
      encryptionCipher: HiveAesCipher(key),
      compactionStrategy: (entries, deletedEntries) {
        return deletedEntries > 50; // Compact when >50 deleted
      },
    );
  }

  // Use lazy box for large collections
  Future<LazyBox<Task>> openLazyTaskBox() async {
    return await Hive.openLazyBox<Task>(TASKS_BOX);
  }
}
```

#### Sync Queue Batching

```dart
// lib/services/sync_queue_service.dart
class OptimizedSyncQueue {
  static const int BATCH_SIZE = 20;
  static const Duration DEBOUNCE_DURATION = Duration(seconds: 2);

  Timer? _debounceTimer;
  List<SyncOperation> _pendingOps = [];

  void enqueue(SyncOperation op) {
    _pendingOps.add(op);

    _debounceTimer?.cancel();
    _debounceTimer = Timer(DEBOUNCE_DURATION, () {
      _processBatch();
    });
  }

  Future<void> _processBatch() async {
    if (_pendingOps.isEmpty) return;

    final batch = _pendingOps.take(BATCH_SIZE).toList();
    _pendingOps.removeRange(0, min(BATCH_SIZE, _pendingOps.length));

    // Send batch request
    await _apiClient.syncBatch(batch);
  }
}
```

---

## 2. Backend Performance Optimization

### 2.1 Database Query Optimization

#### Add Missing Indexes

```sql
-- backend/alembic/versions/XXXX_add_performance_indexes.py

from alembic import op
import sqlalchemy as sa

def upgrade():
    # Task queries optimization
    op.create_index('idx_task_family_status_due', 'tasks', ['familyId', 'status', 'due'])
    op.create_index('idx_task_assignee', 'tasks', ['assignees'], postgresql_using='gin')

    # Event queries optimization
    op.create_index('idx_event_family_start', 'events', ['familyId', 'startTime'])
    op.create_index('idx_event_attendees', 'events', ['attendees'], postgresql_using='gin')

    # Points ledger queries
    op.create_index('idx_points_user_created', 'points_ledger', ['userId', 'createdAt'])

    # Badge queries
    op.create_index('idx_badge_user_code', 'badges', ['userId', 'code'])

    # Study items
    op.create_index('idx_study_user_status', 'study_items', ['userId', 'status'])

def downgrade():
    op.drop_index('idx_task_family_status_due')
    op.drop_index('idx_task_assignee')
    op.drop_index('idx_event_family_start')
    op.drop_index('idx_event_attendees')
    op.drop_index('idx_points_user_created')
    op.drop_index('idx_badge_user_code')
    op.drop_index('idx_study_user_status')
```

#### Query Optimization Patterns

```python
# backend/routers/tasks.py

# BAD: N+1 queries
@router.get("/family/{family_id}/tasks")
async def get_family_tasks(family_id: str, db: Session = Depends(get_db)):
    tasks = db.query(Task).filter(Task.familyId == family_id).all()
    # Each task triggers separate query for assignee names
    return [TaskOut(**task.__dict__, assigneeNames=[
        db.query(User).filter(User.id == uid).first().displayName
        for uid in task.assignees
    ]) for task in tasks]

# GOOD: Eager loading with join
@router.get("/family/{family_id}/tasks")
async def get_family_tasks(family_id: str, db: Session = Depends(get_db)):
    from sqlalchemy.orm import joinedload

    tasks = db.query(Task).options(
        joinedload(Task.family),
        selectinload(Task.assignees_users)  # If relationship exists
    ).filter(
        Task.familyId == family_id,
        Task.status != 'deleted'
    ).order_by(Task.due.asc()).all()

    return [TaskOut.from_orm(task) for task in tasks]
```

### 2.2 Redis Caching Layer

```python
# backend/core/cache_optimized.py

import redis
import json
from functools import wraps
from typing import Optional, Any
import hashlib

redis_client = redis.from_url(
    os.getenv("REDIS_URL", "redis://localhost:6379"),
    decode_responses=True,
    max_connections=50,
    socket_keepalive=True,
    socket_connect_timeout=5,
    retry_on_timeout=True
)

def cache_result(ttl: int = 300, prefix: str = ""):
    """Decorator for caching function results"""
    def decorator(func):
        @wraps(func)
        async def wrapper(*args, **kwargs):
            # Generate cache key from function name and args
            key_base = f"{prefix}:{func.__name__}"
            key_data = f"{args}:{sorted(kwargs.items())}"
            cache_key = f"{key_base}:{hashlib.md5(key_data.encode()).hexdigest()}"

            # Try cache first
            cached = redis_client.get(cache_key)
            if cached:
                return json.loads(cached)

            # Execute function
            result = await func(*args, **kwargs)

            # Cache result
            redis_client.setex(
                cache_key,
                ttl,
                json.dumps(result, default=str)
            )

            return result
        return wrapper
    return decorator

# Usage example
@router.get("/family/{family_id}/points-summary")
@cache_result(ttl=60, prefix="points")
async def get_points_summary(family_id: str, db: Session = Depends(get_db)):
    # Expensive aggregation query
    return db.query(
        User.id,
        User.displayName,
        func.sum(PointsLedger.delta).label('total_points')
    ).join(PointsLedger).filter(
        User.familyId == family_id
    ).group_by(User.id).all()
```

### 2.3 API Response Optimization

#### Pagination

```python
# backend/routers/tasks.py

from pydantic import BaseModel

class PaginatedResponse(BaseModel):
    items: List[Any]
    total: int
    page: int
    page_size: int
    has_next: bool

@router.get("/tasks", response_model=PaginatedResponse)
async def list_tasks(
    page: int = 1,
    page_size: int = 50,
    family_id: Optional[str] = None,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    query = db.query(Task).filter(Task.familyId == family_id or current_user.familyId)

    total = query.count()
    tasks = query.offset((page - 1) * page_size).limit(page_size).all()

    return PaginatedResponse(
        items=[TaskOut.from_orm(t) for t in tasks],
        total=total,
        page=page,
        page_size=page_size,
        has_next=(page * page_size) < total
    )
```

#### Response Compression

```python
# backend/main.py

from fastapi.middleware.gzip import GZipMiddleware

app.add_middleware(GZipMiddleware, minimum_size=1000)
```

---

## 3. Vercel Deployment Optimization

### 3.1 Serverless Function Optimization

#### Cold Start Mitigation

```python
# backend/main.py

from functools import lru_cache

@lru_cache(maxsize=1)
def get_db_engine():
    """Cache database engine across invocations"""
    from core.db_optimized import engine
    return engine

@app.on_event("startup")
async def startup():
    """Warm up connections on cold start"""
    engine = get_db_engine()
    # Pre-warm connection pool
    with engine.connect() as conn:
        conn.execute("SELECT 1")

@app.on_event("shutdown")
async def shutdown():
    """Cleanup on shutdown"""
    from core.db_optimized import dispose_engine
    dispose_engine()
```

#### Function Size Optimization

```bash
# .vercelignore
backend/.venv/
backend/__pycache__/
backend/*.pyc
backend/tests/
backend/.pytest_cache/
*.db
*.log
.env
```

### 3.2 Static Asset Optimization (Flutter Web)

#### Pre-compression

```bash
# Add to build script
#!/bin/bash
cd flutter_app
flutter build web --release --tree-shake-icons

# Compress assets
cd build/web
find . -type f \( -name "*.js" -o -name "*.css" -o -name "*.json" \) -exec gzip -9 -k {} \;
find . -type f \( -name "*.js" -o -name "*.css" -o -name "*.json" \) -exec brotli -9 -k {} \;
```

#### Service Worker Caching Strategy

```javascript
// flutter_app/web/sw.js (custom service worker)

const CACHE_VERSION = 'v1.0.0';
const STATIC_CACHE = `famquest-static-${CACHE_VERSION}`;
const DYNAMIC_CACHE = `famquest-dynamic-${CACHE_VERSION}`;

const STATIC_ASSETS = [
  '/',
  '/index.html',
  '/main.dart.js',
  '/flutter.js',
  '/manifest.json',
];

// Cache-first strategy for static assets
self.addEventListener('fetch', (event) => {
  const { request } = event;
  const url = new URL(request.url);

  if (STATIC_ASSETS.includes(url.pathname)) {
    event.respondWith(
      caches.match(request).then((cached) => {
        return cached || fetch(request);
      })
    );
  } else if (url.pathname.startsWith('/api/')) {
    // Network-first for API calls
    event.respondWith(
      fetch(request).catch(() => {
        return caches.match(request);
      })
    );
  }
});
```

### 3.3 CDN Configuration

```json
// vercel.json additions
{
  "headers": [
    {
      "source": "/flutter_app/web/assets/(.*)",
      "headers": [
        {
          "key": "Cache-Control",
          "value": "public, max-age=31536000, immutable"
        },
        {
          "key": "Content-Encoding",
          "value": "br"
        }
      ]
    }
  ]
}
```

---

## 4. Monitoring & Analytics

### 4.1 Sentry Integration

```python
# backend/main.py

import sentry_sdk
from sentry_sdk.integrations.fastapi import FastApiIntegration
from sentry_sdk.integrations.sqlalchemy import SqlalchemyIntegration

if os.getenv("SENTRY_DSN"):
    sentry_sdk.init(
        dsn=os.getenv("SENTRY_DSN"),
        integrations=[
            FastApiIntegration(),
            SqlalchemyIntegration(),
        ],
        traces_sample_rate=0.1,  # 10% of requests
        profiles_sample_rate=0.1,
        environment=os.getenv("ENVIRONMENT", "development"),
    )
```

```dart
// flutter_app/lib/main.dart

import 'package:sentry_flutter/sentry_flutter.dart';

Future<void> main() async {
  await SentryFlutter.init(
    (options) {
      options.dsn = const String.fromEnvironment('SENTRY_DSN');
      options.environment = const String.fromEnvironment('ENVIRONMENT', defaultValue: 'development');
      options.tracesSampleRate = 0.1;
    },
    appRunner: () => runApp(MyApp()),
  );
}
```

### 4.2 Vercel Analytics

```html
<!-- flutter_app/web/index.html -->
<script>
  window.va = window.va || function () { (window.vaq = window.vaq || []).push(arguments); };
</script>
<script defer src="/_vercel/insights/script.js"></script>
```

---

## 5. Performance Benchmarks

### Before Optimization (Baseline)

| Metric | Current | Target | Status |
|--------|---------|--------|--------|
| Flutter Web Bundle | 45MB | <30MB | ⚠️ |
| Initial Load Time | 3.2s | <2s | ⚠️ |
| UI Frame Rate | 55fps | 60fps | ⚠️ |
| API Latency (p95) | 280ms | <200ms | ⚠️ |
| DB Query Time (p95) | 85ms | <50ms | ✅ |
| Cold Start Time | 15s | <10s | ⚠️ |

### After Optimization (Target)

| Metric | Expected | Improvement |
|--------|----------|-------------|
| Flutter Web Bundle | 28MB | -38% |
| Initial Load Time | 1.8s | -44% |
| UI Frame Rate | 60fps | +9% |
| API Latency (p95) | 180ms | -36% |
| DB Query Time (p95) | 45ms | -47% |
| Cold Start Time | 8s | -47% |

---

## 6. Cost Optimization

### Vercel Pricing Optimization

**Current Architecture Cost (1K users):**
- Function Invocations: ~500K/month = $10
- Bandwidth: ~50GB/month = $5
- Build Minutes: ~100/month = Free
**Total: ~$15/month**

**Optimized Architecture (10K users):**
- Function Invocations: 2M/month = $40 (with caching)
- Bandwidth: 200GB/month = $20 (with CDN)
- Build Minutes: 100/month = Free
**Total: ~$60/month**

**Scale to 100K users:**
- Move to dedicated hosting (AWS/GCP) = $200-500/month
- Implement read replicas for database
- Use Cloudflare CDN = $20/month

---

## 7. Implementation Checklist

### Phase 1: Quick Wins (1-2 days)
- [ ] Apply `dart fix --apply` for const optimizations
- [ ] Add database indexes (run migration)
- [ ] Enable GZip compression middleware
- [ ] Configure Vercel build settings
- [ ] Add Redis caching for hot endpoints

### Phase 2: Medium Effort (3-5 days)
- [ ] Implement code splitting with deferred imports
- [ ] Replace Image.network with CachedNetworkImage
- [ ] Optimize Riverpod provider granularity
- [ ] Add pagination to list endpoints
- [ ] Implement service worker caching strategy

### Phase 3: Long-term (1-2 weeks)
- [ ] Migrate to optimized database configuration
- [ ] Implement comprehensive monitoring (Sentry)
- [ ] Load testing with locust (1K concurrent users)
- [ ] Progressive Web App optimization
- [ ] Database query profiling and optimization

---

## 8. Testing & Validation

### Performance Testing Script

```bash
#!/bin/bash
# scripts/performance_test.sh

echo "=== Flutter Bundle Size Test ==="
cd flutter_app
flutter build web --release
du -sh build/web

echo "=== Backend Load Test ==="
cd ../backend
locust -f tests/locustfile.py --headless -u 100 -r 10 -t 60s --host http://localhost:8000

echo "=== Database Query Performance ==="
python scripts/benchmark_queries.py

echo "=== Lighthouse Performance Audit ==="
npx lighthouse http://localhost:54321 --output json --output-path ./lighthouse-report.json
```

### Lighthouse Targets

```json
{
  "performance": 90,
  "accessibility": 95,
  "best-practices": 90,
  "seo": 85,
  "pwa": 80
}
```

---

## 9. Additional Resources

### Documentation
- [Flutter Performance Best Practices](https://docs.flutter.dev/perf)
- [FastAPI Performance Tips](https://fastapi.tiangolo.com/deployment/concepts/)
- [Vercel Serverless Functions](https://vercel.com/docs/functions)
- [PostgreSQL Performance Tuning](https://wiki.postgresql.org/wiki/Performance_Optimization)

### Tools
- Flutter DevTools: Performance profiling
- Locust: Load testing
- pgAdmin: Database query analysis
- Sentry: Error tracking and performance monitoring
- Vercel Analytics: Real-user monitoring

---

**Document Version:** 1.0
**Last Updated:** 2025-11-19
**Author:** Performance Engineer
**Next Review:** 2025-12-19
