import os
from typing import AsyncGenerator
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession, async_sessionmaker
from sqlalchemy.orm import declarative_base
from urllib.parse import urlparse, parse_qs, urlencode, urlunparse
from config import settings

def clean_async_db_url(raw_url: str) -> str:
    url = raw_url or os.getenv("DATABASE_URL", "")
    if not url:
        return url

    # Force driver scheme
    if url.startswith("postgresql://"):
        url = url.replace("postgresql://", "postgresql+asyncpg://", 1)
    elif url.startswith("postgres://"):
        url = url.replace("postgres://", "postgresql+asyncpg://", 1)

    # Strip ALL query parameters from URL string to prevent asyncpg keyword argument crashes
    if "?" in url:
        url = url.split("?")[0]

    return url

async_db_url = clean_async_db_url(settings.DATABASE_URL)

# Use SSL only for cloud databases (Neon, Supabase, etc.)
# Local PostgreSQL doesn't support SSL by default
db_url_lower = async_db_url.lower()
use_ssl = any(host in db_url_lower for host in ["neon.tech", "supabase.co", "aws.neon", "pooler.supabase"])
import uuid

def _get_unique_prep_stmt_name(*args):
    return f"__asyncpg_stmt_{uuid.uuid4().hex}__"

connect_args = {
    "statement_cache_size": 0,
    "prepared_statement_cache_size": 0,
    "prepared_statement_name_func": _get_unique_prep_stmt_name
}
if use_ssl:
    connect_args["ssl"] = "require"

engine = create_async_engine(
    async_db_url,
    echo=False,
    future=True,
    pool_size=10,
    max_overflow=5,
    pool_pre_ping=True,
    connect_args=connect_args
)

AsyncSessionLocal = async_sessionmaker(
    bind=engine,
    class_=AsyncSession,
    expire_on_commit=False,
    autocommit=False,
    autoflush=False
)

Base = declarative_base()

async def get_db() -> AsyncGenerator[AsyncSession, None]:
    async with AsyncSessionLocal() as session:
        try:
            yield session
            await session.commit()
        except Exception:
            await session.rollback()
            raise
        finally:
            await session.close()
