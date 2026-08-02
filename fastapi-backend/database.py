from typing import AsyncGenerator
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession, async_sessionmaker
from sqlalchemy.orm import declarative_base
from config import settings

# Format database URL for asyncpg engine compatibility
raw_db_url = settings.DATABASE_URL
if raw_db_url.startswith("postgresql://"):
    async_db_url = raw_db_url.replace("postgresql://", "postgresql+asyncpg://", 1)
elif raw_db_url.startswith("postgres://"):
    async_db_url = raw_db_url.replace("postgres://", "postgresql+asyncpg://", 1)
else:
    async_db_url = raw_db_url

# Handle SSL parameter for asyncpg
if "sslmode=" in async_db_url:
    async_db_url = async_db_url.replace("sslmode=require", "ssl=require")

engine = create_async_engine(
    async_db_url,
    echo=False,
    future=True,
    pool_size=20,
    max_overflow=10,
    pool_pre_ping=True
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
