import os
from typing import Optional
from pydantic_settings import BaseSettings, SettingsConfigDict
from dotenv import load_dotenv

load_dotenv()

class Settings(BaseSettings):
    APP_NAME: str = "FastKirana FastAPI Microservice"
    APP_ENV: str = os.getenv("NODE_ENV", "development")
    DEBUG: bool = os.getenv("DEBUG", "False").lower() == "true"

    # Database Configuration
    DATABASE_URL: str = os.getenv("DATABASE_URL", "")
    
    # Optional Upstash Redis Caching URL (e.g. rediss://default:token@xxx.upstash.io:6379)
    REDIS_URL: Optional[str] = os.getenv("REDIS_URL", None)

    # Optional Sentry Error Monitoring DSN
    SENTRY_DSN: Optional[str] = os.getenv("SENTRY_DSN", None)

    # JWT Authentication Config
    AUTH_SECRET: str = os.getenv("AUTH_SECRET", "")
    ALGORITHM: str = "HS256"

    # Store Defaults
    DEFAULT_RIDER_CASH_LIMIT: float = 2000.0

    model_config = SettingsConfigDict(case_sensitive=True)

settings = Settings()
