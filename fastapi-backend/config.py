import os
from typing import Optional
from pydantic_settings import BaseSettings, SettingsConfigDict
from dotenv import load_dotenv

load_dotenv()

class Settings(BaseSettings):
    APP_NAME: str = "FastKirana FastAPI Microservice"
    APP_ENV: str = os.getenv("APP_ENV", "development")
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

    # Razorpay Payment Gateway Credentials
    RAZORPAY_KEY_ID: str = os.getenv("RAZORPAY_KEY_ID", "")
    RAZORPAY_KEY_SECRET: str = os.getenv("RAZORPAY_KEY_SECRET", "")

    # Google Maps API Key
    GOOGLE_MAPS_API_KEY: str = os.getenv("GOOGLE_MAPS_API_KEY", "")

    # Cashfree Payment Gateway Credentials
    CASHFREE_APP_ID: str = os.getenv("CASHFREE_APP_ID", "")
    CASHFREE_SECRET_KEY: str = os.getenv("CASHFREE_SECRET_KEY", "")
    CASHFREE_ENV: str = os.getenv("CASHFREE_ENV", "PRODUCTION")
    CASHFREE_API_VERSION: str = os.getenv("CASHFREE_API_VERSION", "2023-08-01")

    # App & Frontend URL
    NEXT_PUBLIC_APP_URL: str = os.getenv("NEXT_PUBLIC_APP_URL", "https://fastkirana.in")

    # Supabase Configuration
    NEXT_PUBLIC_SUPABASE_URL: str = os.getenv("NEXT_PUBLIC_SUPABASE_URL", "https://bberzasmxwioxjynbuaf.supabase.co")
    NEXT_PUBLIC_SUPABASE_ANON_KEY: str = os.getenv("NEXT_PUBLIC_SUPABASE_ANON_KEY", "sb_publishable_txJDOmH1qWQuOLCKrnV69A_RQ1XS4o-")
    SUPABASE_SERVICE_ROLE_KEY: Optional[str] = os.getenv("SUPABASE_SERVICE_ROLE_KEY", None)

    model_config = SettingsConfigDict(case_sensitive=True)

settings = Settings()
