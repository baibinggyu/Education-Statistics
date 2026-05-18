from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, declarative_base
import os
_db_host = os.getenv("education_statistics_db_host", "127.0.0.1")
_db_port = os.getenv("education_statistics_db_port", "3306")
_db_name = os.getenv("education_statistics_db_name", "edu_server_database")
_db_user = os.getenv("education_statistics_db_user", "edu_user")
_db_pass = os.getenv("education_statistics_passwd")
DATABASE_URL = f"mysql+pymysql://{_db_user}:{_db_pass}@{_db_host}:{_db_port}/{_db_name}?charset=utf8mb4"

_echo = os.getenv("education_statistics_echo", "false").lower() in ("1", "true", "yes")
engine = create_engine(
    DATABASE_URL,
    pool_pre_ping=True,
    pool_recycle=3600,
    pool_size=10,
    max_overflow=20,
    echo=_echo,
)

SessionLocal = sessionmaker(
    bind=engine,
    autocommit=False,
    autoflush=False,
)

Base = declarative_base()


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
