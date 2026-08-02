import os
from pydantic_settings import BaseSettings, SettingsConfigDict
from dotenv import load_dotenv

load_dotenv()

class Settings(BaseSettings):
    APP_NAME: str = "FastKirana FastAPI Microservice"
    APP_ENV: str = os.getenv("NODE_ENV", "development")
    DEBUG: bool = os.getenv("DEBUG", "True").lower() == "true"

    # Database Configuration (Neon PostgreSQL)
    DATABASE_URL: str = os.getenv("DATABASE_URL", "postgresql+asyncpg://neondb_owner:npg_g0hWSj4wOqZp@ep-crimson-term-ao9b30gv.c-2.ap-southeast-1.aws.neon.tech/neondb?ssl=require")
    
    # JWT Authentication Config
    AUTH_SECRET: str = os.getenv("AUTH_SECRET", "super-secret-auth-key")
    ALGORITHM: str = "HS256"

    # Store Defaults
    DEFAULT_RIDER_CASH_LIMIT: float = 2000.0

    model_config = SettingsConfigDict(case_sensitive=True)

settings = Settings()
