import os
from dotenv import load_dotenv
from sqlmodel import create_engine, Session

load_dotenv()

DATABASE_URL = os.getenv("DATABASE_URL")

# Engine configured for thread safety and Neon serverless connection pooling
engine = create_engine(
    DATABASE_URL,
    pool_pre_ping=True,
    pool_recycle=300,
    echo=False
)

def get_session():
    with Session(engine) as session:
        yield session
