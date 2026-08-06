from typing import AsyncGenerator
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession, async_sessionmaker
from sqlalchemy.orm import declarative_base
from urllib.parse import urlparse, parse_qs, urlencode, urlunparse
from config import settings

def clean_async_db_url(url: str) -> str:
    if url.startswith("postgresql://"):
        url = url.replace("postgresql://", "postgresql+asyncpg://", 1)
    elif url.startswith("postgres://"):
        url = url.replace("postgres://", "postgresql+asyncpg://", 1)

    parsed = urlparse(url)
    query_params = parse_qs(parsed.query)

    # Filter out query parameters not supported in URL query string by asyncpg driver
    unsupported = ["connection_limit", "pool_timeout", "schema", "sslmode", "ssl"]
    filtered_params = {k: v for k, v in query_params.items() if k not in unsupported}

    new_query = urlencode(filtered_params, doseq=True)
    cleaned = urlunparse((
        parsed.scheme,
        parsed.netloc,
        parsed.path,
        parsed.params,
        new_query,
        parsed.fragment
    ))
    return cleaned

async_db_url = clean_async_db_url(settings.DATABASE_URL)

# Use SSL only for cloud databases (Neon, Supabase, etc.)
# Local PostgreSQL doesn't support SSL by default
db_url_lower = async_db_url.lower()
use_ssl = any(host in db_url_lower for host in ["neon.tech", "supabase.co", "aws.neon", "pooler.supabase"])
connect_args = {"ssl": "require"} if use_ssl else {}

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
