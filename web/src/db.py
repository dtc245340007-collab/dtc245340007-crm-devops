import os
from contextlib import contextmanager
import psycopg2
from psycopg2.pool import ThreadedConnectionPool
from psycopg2.extras import RealDictCursor

_pool = None

def get_pool():
    global _pool
    if _pool is None:
        _pool = ThreadedConnectionPool(
            minconn=1,
            maxconn=20,
            host=os.environ.get("DB_HOST", "db"),
            port=int(os.environ.get("DB_PORT", 5432)),
            dbname=os.environ.get("DB_NAME", "crm"),
            user=os.environ.get("DB_USER", "crm_app"),
            password=os.environ.get("DB_PASSWORD", "")
        )
    return _pool

@contextmanager
def get_db():
    """Context manager for obtaining a database cursor with automatic commit/rollback and reconnect."""
    pool = get_pool()
    conn = pool.getconn()
    try:
        # Check connection status
        if conn.closed != 0:
            conn = pool.getconn()
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            yield cur
        conn.commit()
    except (psycopg2.OperationalError, psycopg2.InterfaceError):
        try:
            conn.rollback()
        except Exception:
            pass
        pool.putconn(conn, close=True)
        raise
    except Exception:
        try:
            conn.rollback()
        except Exception:
            pass
        raise
    finally:
        if conn.closed == 0:
            pool.putconn(conn)
