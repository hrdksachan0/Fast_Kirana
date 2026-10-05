import sys
import os

# Set hermetic defaults for testing before application modules load
os.environ.setdefault("AUTH_SECRET", "ci_test_auth_secret_key_32chars_long_000")
os.environ.setdefault("INTERNAL_API_SECRET", "ci_test_secret_32chars_long_key_00")
os.environ.setdefault("CASHFREE_ENV", "TEST")

import pytest
import pytest_asyncio
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession, async_sessionmaker
from sqlalchemy.orm import declarative_base

sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from database import Base, get_db
from main import app
import models

from sqlalchemy.pool import StaticPool

# In-memory SQLite async engine for fast, isolated backend testing
TEST_DATABASE_URL = "sqlite+aiosqlite:///file:testmemdb?mode=memory&cache=shared&uri=true"

test_engine = create_async_engine(
    TEST_DATABASE_URL,
    echo=False,
    future=True,
    poolclass=StaticPool,
    connect_args={"check_same_thread": False},
)

TestingSessionLocal = async_sessionmaker(
    bind=test_engine,
    class_=AsyncSession,
    expire_on_commit=False,
)

@pytest_asyncio.fixture(scope="function", autouse=True)
async def prepare_database():
    async with test_engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
    yield
    async with test_engine.begin() as conn:
        await conn.run_sync(Base.metadata.drop_all)

async def override_get_db():
    async with TestingSessionLocal() as session:
        try:
            yield session
            await session.commit()
        except Exception:
            await session.rollback()
            raise
        finally:
            await session.close()

app.dependency_overrides[get_db] = override_get_db
