"""
Optimized Database Configuration for Production Deployment
Includes connection pooling, query optimization, and monitoring
"""
import os
from contextlib import asynccontextmanager
from sqlalchemy import create_engine, event, pool
from sqlalchemy.orm import sessionmaker, declarative_base
from sqlalchemy.engine import Engine
import logging

logger = logging.getLogger(__name__)

# Database URL with fallback
DATABASE_URL = os.getenv("DATABASE_URL", "sqlite:///./famquest.db")
IS_SQLITE = DATABASE_URL.startswith("sqlite")
IS_PRODUCTION = os.getenv("ENVIRONMENT", "development") == "production"

# Connection Pool Configuration
POOL_CONFIG = {
    # PostgreSQL Production Settings
    "postgresql": {
        "pool_size": 10,  # Base connection pool size
        "max_overflow": 20,  # Max additional connections
        "pool_timeout": 30,  # Seconds to wait for connection
        "pool_recycle": 3600,  # Recycle connections after 1 hour
        "pool_pre_ping": True,  # Verify connections before use
        "echo": False,  # Disable SQL logging in production
        "echo_pool": False,
    },
    # SQLite Development Settings
    "sqlite": {
        "check_same_thread": False,
        "pool_size": 5,
        "max_overflow": 10,
        "echo": True,  # Enable logging in development
    }
}

# Query Performance Monitoring
if IS_PRODUCTION:
    @event.listens_for(Engine, "before_cursor_execute")
    def before_cursor_execute(conn, cursor, statement, parameters, context, executemany):
        conn.info.setdefault("query_start_time", []).append(
            __import__("time").perf_counter()
        )

    @event.listens_for(Engine, "after_cursor_execute")
    def after_cursor_execute(conn, cursor, statement, parameters, context, executemany):
        total_time = __import__("time").perf_counter() - conn.info["query_start_time"].pop(-1)
        if total_time > 0.1:  # Log slow queries (>100ms)
            logger.warning(
                f"Slow query detected ({total_time:.3f}s): {statement[:200]}"
            )

# Create Engine with Optimized Settings
def create_optimized_engine():
    """Create SQLAlchemy engine with production-optimized settings"""

    if IS_SQLITE:
        # SQLite for development/testing
        return create_engine(
            DATABASE_URL,
            connect_args=POOL_CONFIG["sqlite"],
            poolclass=pool.StaticPool,
            echo=POOL_CONFIG["sqlite"]["echo"]
        )
    else:
        # PostgreSQL for production with connection pooling
        return create_engine(
            DATABASE_URL,
            pool_size=POOL_CONFIG["postgresql"]["pool_size"],
            max_overflow=POOL_CONFIG["postgresql"]["max_overflow"],
            pool_timeout=POOL_CONFIG["postgresql"]["pool_timeout"],
            pool_recycle=POOL_CONFIG["postgresql"]["pool_recycle"],
            pool_pre_ping=POOL_CONFIG["postgresql"]["pool_pre_ping"],
            echo=POOL_CONFIG["postgresql"]["echo"],
            echo_pool=POOL_CONFIG["postgresql"]["echo_pool"],
            # Enable statement caching for better performance
            execution_options={
                "compiled_cache": {},
            }
        )

# Initialize engine and session
engine = create_optimized_engine()
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()

# Database Health Check
def check_database_health():
    """Verify database connection and return health status"""
    try:
        with engine.connect() as conn:
            conn.execute("SELECT 1")
        return {
            "status": "healthy",
            "pool_size": engine.pool.size(),
            "checked_out": engine.pool.checkedout(),
            "overflow": engine.pool.overflow(),
            "checked_in": engine.pool.checkedin()
        }
    except Exception as e:
        logger.error(f"Database health check failed: {e}")
        return {"status": "unhealthy", "error": str(e)}

# Async context manager for sessions
@asynccontextmanager
async def get_async_session():
    """Async context manager for database sessions"""
    session = SessionLocal()
    try:
        yield session
        session.commit()
    except Exception:
        session.rollback()
        raise
    finally:
        session.close()

# Connection pool status endpoint
def get_pool_stats():
    """Get current connection pool statistics"""
    return {
        "size": engine.pool.size(),
        "checked_out": engine.pool.checkedout(),
        "overflow": engine.pool.overflow(),
        "checked_in": engine.pool.checkedin(),
        "timeout": POOL_CONFIG["postgresql"]["pool_timeout"] if not IS_SQLITE else None
    }

# Graceful shutdown
def dispose_engine():
    """Dispose engine connections gracefully"""
    logger.info("Disposing database engine...")
    engine.dispose()
    logger.info("Database engine disposed successfully")
