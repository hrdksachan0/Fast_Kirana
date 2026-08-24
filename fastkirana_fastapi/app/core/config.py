import os
from dotenv import load_dotenv

load_dotenv()

class Settings:
    PROJECT_NAME: str = "FastKirana API"
    VERSION: str = "1.0.0"
    API_PREFIX: str = "/api"
    
    DATABASE_URL: str = os.getenv(
        "DATABASE_URL",
        "postgresql://postgres.bberzasmxwioxjynbuaf:YuvrajHardik%402613@aws-0-ap-south-1.pooler.supabase.com:5432/postgres"
    )
    SUPABASE_URL: str = os.getenv("SUPABASE_URL", "https://bberzasmxwioxjynbuaf.supabase.co")
    SUPABASE_ANON_KEY: str = os.getenv("SUPABASE_ANON_KEY", "sb_publishable_txJDOmH1qWQuOLCKrnV69A_RQ1XS4o-")
    JWT_SECRET: str = os.getenv("JWT_SECRET", "supersecretkey1234567890abcdef123456")
    ADMIN_USER_ID: str = os.getenv("ADMIN_USER_ID", "cmqgzqeud0000vkid7hd6mti4")

settings = Settings()
