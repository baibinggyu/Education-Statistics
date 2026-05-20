import uuid
from sqlalchemy import (
    Column, BigInteger, String, Integer, Float, Boolean,
    Text, DateTime, Enum, ForeignKey, UniqueConstraint,
)
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from .database import Base


def _new_uuid() -> str:
    return str(uuid.uuid4())


class User(Base):
    __tablename__ = "users"

    id = Column(BigInteger, primary_key=True, autoincrement=True)
    uuid = Column(String(36), unique=True, nullable=False, default=_new_uuid)
    username = Column(String(64), unique=True, nullable=False)
    password_hash = Column(String(255), nullable=False)
    role = Column(Enum("student", "teacher", "admin"), nullable=False)
    status = Column(Integer, nullable=False, default=1)
    created_at = Column(DateTime, server_default=func.now())


class Student(Base):
    __tablename__ = "students"

    id = Column(BigInteger, primary_key=True, autoincrement=True)
    user_id = Column(BigInteger, ForeignKey("users.id"), unique=True, nullable=False)
    student_no = Column(String(64), unique=True, nullable=False)
    real_name = Column(String(64), nullable=False)
    created_at = Column(DateTime, server_default=func.now())


class Course(Base):
    __tablename__ = "courses"

    id = Column(BigInteger, primary_key=True, autoincrement=True)
    uuid = Column(String(36), unique=True, nullable=False, default=_new_uuid)
    name = Column(String(128), nullable=False)
    description = Column(Text, nullable=True)
    teacher_id = Column(BigInteger, ForeignKey("users.id"), nullable=False)
    status = Column(Enum("normal", "hidden", "deleted"), nullable=False, default="normal")
    created_at = Column(DateTime, server_default=func.now())

    teacher = relationship("User", foreign_keys=[teacher_id])


class CourseMember(Base):
    __tablename__ = "course_members"

    id = Column(BigInteger, primary_key=True, autoincrement=True)
    course_id = Column(BigInteger, ForeignKey("courses.id"), nullable=False)
    user_id = Column(BigInteger, ForeignKey("users.id"), nullable=False)
    member_role = Column(Enum("student", "teacher"), nullable=False, default="student")
    created_at = Column(DateTime, server_default=func.now())

    __table_args__ = (
        UniqueConstraint("course_id", "user_id", name="uk_course_user"),
    )


class Unit(Base):
    __tablename__ = "units"

    id = Column(BigInteger, primary_key=True, autoincrement=True)
    course_id = Column(BigInteger, ForeignKey("courses.id"), nullable=False)
    name = Column(String(128), nullable=False)
    weight = Column(Float, nullable=False, default=0)
    full_score = Column(Float, nullable=False, default=100)
    unit_order = Column(Integer, nullable=False, default=0)
    created_at = Column(DateTime, server_default=func.now())

    __table_args__ = (
        UniqueConstraint("course_id", "name", name="uk_course_unit_name"),
    )


class Score(Base):
    __tablename__ = "scores"

    id = Column(BigInteger, primary_key=True, autoincrement=True)
    student_id = Column(BigInteger, ForeignKey("students.id"), nullable=False)
    course_id = Column(BigInteger, ForeignKey("courses.id"), nullable=False)
    unit_id = Column(BigInteger, ForeignKey("units.id"), nullable=False)
    score = Column(Float, nullable=False, default=0)
    created_at = Column(DateTime, server_default=func.now())
    updated_at = Column(DateTime, server_default=func.now(), onupdate=func.now())

    __table_args__ = (
        UniqueConstraint("student_id", "course_id", "unit_id", name="uk_student_course_unit"),
    )


class Video(Base):
    __tablename__ = "videos"

    id = Column(BigInteger, primary_key=True, autoincrement=True)
    uuid = Column(String(36), unique=True, nullable=False, default=_new_uuid)
    course_id = Column(BigInteger, ForeignKey("courses.id"), nullable=False)
    uploader_id = Column(BigInteger, ForeignKey("users.id"), nullable=False)
    title = Column(String(255), nullable=False)
    description = Column(Text, nullable=True)
    file_path = Column(String(255), nullable=False)
    cover_path = Column(String(255), nullable=True)
    duration = Column(Integer, nullable=False, default=0)
    file_size = Column(BigInteger, nullable=False, default=0)
    status = Column(Enum("normal", "hidden", "deleted"), nullable=False, default="normal")
    created_at = Column(DateTime, server_default=func.now())
    updated_at = Column(DateTime, server_default=func.now(), onupdate=func.now())

    course = relationship("Course", foreign_keys=[course_id])
    uploader = relationship("User", foreign_keys=[uploader_id])


class PlayRecord(Base):
    __tablename__ = "play_records"

    id = Column(BigInteger, primary_key=True, autoincrement=True)
    user_id = Column(BigInteger, ForeignKey("users.id"), nullable=False)
    video_id = Column(BigInteger, ForeignKey("videos.id"), nullable=False)
    progress = Column(Integer, nullable=False, default=0)
    completed = Column(Boolean, nullable=False, default=False)
    last_played_at = Column(DateTime, server_default=func.now(), onupdate=func.now())

    __table_args__ = (
        UniqueConstraint("user_id", "video_id", name="uk_user_video"),
    )
