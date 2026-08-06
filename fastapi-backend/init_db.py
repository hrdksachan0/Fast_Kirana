"""
Database initialization script.
Run with: python init_db.py
"""

import asyncio
from database import engine, Base
import models  # noqa: F401 — register all models

async def init_db():
    async with engine.begin() as conn:
        # Drop all (CAUTION: only for dev)
        # await conn.run_sync(Base.metadata.drop_all)
        # Create all
        await conn.run_sync(Base.metadata.create_all)
    print("✅ Database tables created successfully")

if __name__ == "__main__":
    asyncio.run(init_db())