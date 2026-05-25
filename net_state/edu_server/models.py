import uuid

from sqlalchemy import (
    BigInteger,
    Boolean,
    Column,
    DateTime,
    Enum,
    Float,
    ForeignKey,
    Integer,
    String,
    Text,
    UniqueConstraint,
)
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func

from database import Base


class User(Base):
    __tablename__ = "users"

    id = Column(BigInteger, primary_key=True, autoincrement=True)
    uuid = Column(
        String(36), unique=True, nullable=False, default=lambda: str(uuid.uuid4())
    )

    username = Column(String(64), unique=True, nullable=False)
    password_hash = Column(String(255), nullable=False)

    role = Column(Enum("student", "teacher", "admin"), nullable=False,default="student")
    status = Column(Integer, nullable=False, default=1)

    created_at = Column(DateTime, server_default=func.now())

    # relationships
    student = relationship("Student", back_populates="user", uselist=False)
    courses_taught = relationship("Course", back_populates="teacher")
    course_memberships = relationship("CourseMember", back_populates="user")
    uploaded_videos = relationship("Video", back_populates="uploader")
    play_records = relationship("PlayRecord", back_populates="user")


class Student(Base):
    __tablename__ = "students"

    id = Column(BigInteger, primary_key=True, autoincrement=True)
    user_id = Column(
        BigInteger, ForeignKey("users.id"), unique=True, nullable=False
    )

    student_no = Column(String(64), unique=True, nullable=False)
    real_name = Column(String(64), nullable=False)

    created_at = Column(DateTime, server_default=func.now())

    # relationships
    user = relationship("User", back_populates="student")
    scores = relationship("Score", back_populates="student")


class Course(Base):
    __tablename__ = "courses"

    id = Column(BigInteger, primary_key=True, autoincrement=True)
    uuid = Column(
        String(36), unique=True, nullable=False, default=lambda: str(uuid.uuid4())
    )

    name = Column(String(128), nullable=False)
    description = Column(Text)

    teacher_id = Column(BigInteger, ForeignKey("users.id"), nullable=False)

    status = Column(
        Enum("normal", "hidden", "deleted"), nullable=False, default="normal"
    )
    created_at = Column(DateTime, server_default=func.now())

    # relationships
    teacher = relationship("User", back_populates="courses_taught")
    members = relationship("CourseMember", back_populates="course")
    units = relationship("Unit", back_populates="course")
    videos = relationship("Video", back_populates="course")
    scores = relationship("Score", back_populates="course")


class CourseMember(Base):
    __tablename__ = "course_members"

    id = Column(BigInteger, primary_key=True, autoincrement=True)

    course_id = Column(BigInteger, ForeignKey("courses.id"), nullable=False)
    user_id = Column(BigInteger, ForeignKey("users.id"), nullable=False)

    member_role = Column(
        Enum("student", "teacher"), nullable=False, default="student"
    )
    created_at = Column(DateTime, server_default=func.now())

    __table_args__ = (
        UniqueConstraint("course_id", "user_id", name="uk_course_user"),
    )

    # relationships
    course = relationship("Course", back_populates="members")
    user = relationship("User", back_populates="course_memberships")


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

    # relationships
    course = relationship("Course", back_populates="units")
    scores = relationship("Score", back_populates="unit")


class Score(Base):
    __tablename__ = "scores"

    id = Column(BigInteger, primary_key=True, autoincrement=True)

    student_id = Column(BigInteger, ForeignKey("students.id"), nullable=False)
    course_id = Column(BigInteger, ForeignKey("courses.id"), nullable=False)
    unit_id = Column(BigInteger, ForeignKey("units.id"), nullable=False)

    score = Column(Float, nullable=False, default=0)

    created_at = Column(DateTime, server_default=func.now())
    updated_at = Column(
        DateTime, server_default=func.now(), onupdate=func.now()
    )

    __table_args__ = (
        UniqueConstraint(
            "student_id", "course_id", "unit_id", name="uk_student_course_unit"
        ),
    )

    # relationships
    student = relationship("Student", back_populates="scores")
    course = relationship("Course", back_populates="scores")
    unit = relationship("Unit", back_populates="scores")


class Video(Base):
    __tablename__ = "videos"

    id = Column(BigInteger, primary_key=True, autoincrement=True)
    uuid = Column(
        String(36), unique=True, nullable=False, default=lambda: str(uuid.uuid4())
    )

    course_id = Column(BigInteger, ForeignKey("courses.id"), nullable=False)
    uploader_id = Column(BigInteger, ForeignKey("users.id"), nullable=False)

    title = Column(String(255), nullable=False)
    description = Column(Text)

    file_path = Column(String(255), nullable=False)
    cover_path = Column(String(255))

    duration = Column(Integer, nullable=False, default=0)
    file_size = Column(BigInteger, nullable=False, default=0)

    status = Column(
        Enum("normal", "hidden", "deleted"), nullable=False, default="normal"
    )

    created_at = Column(DateTime, server_default=func.now())
    updated_at = Column(
        DateTime, server_default=func.now(), onupdate=func.now()
    )

    # relationships
    course = relationship("Course", back_populates="videos")
    uploader = relationship("User", back_populates="uploaded_videos")
    play_records = relationship("PlayRecord", back_populates="video")


class Announcement(Base):
    __tablename__ = "announcements"

    id = Column(BigInteger, primary_key=True, autoincrement=True)
    uuid = Column(
        String(36), unique=True, nullable=False, default=lambda: str(uuid.uuid4())
    )

    course_id = Column(BigInteger, ForeignKey("courses.id"), nullable=False)
    author_id = Column(BigInteger, ForeignKey("users.id"), nullable=False)

    title = Column(String(255), nullable=False)
    content = Column(Text, nullable=False)

    ann_type = Column(
        Enum("课程通知", "作业提醒", "考试安排", "资料更新", "其他"),
        nullable=False,
        default="课程通知",
    )
    pinned = Column(Boolean, nullable=False, default=False)
    notify = Column(Boolean, nullable=False, default=True)

    status = Column(
        Enum("normal", "hidden", "deleted"), nullable=False, default="normal"
    )

    created_at = Column(DateTime, server_default=func.now())
    updated_at = Column(
        DateTime, server_default=func.now(), onupdate=func.now()
    )

    # relationships
    course = relationship("Course", backref="announcements")
    author = relationship("User", backref="announcements")


class Message(Base):
    __tablename__ = "messages"

    id = Column(BigInteger, primary_key=True, autoincrement=True)
    uuid = Column(
        String(36), unique=True, nullable=False, default=lambda: str(uuid.uuid4())
    )

    course_id = Column(BigInteger, ForeignKey("courses.id"), nullable=False)
    sender_id = Column(BigInteger, ForeignKey("users.id"), nullable=False)
    recipient_id = Column(BigInteger, ForeignKey("users.id"), nullable=True)

    subject = Column(String(255))
    content = Column(Text, nullable=False)

    msg_type = Column(
        Enum("学习提醒", "作业通知", "考试安排", "课堂反馈", "其他"),
        nullable=False,
        default="其他",
    )
    is_read = Column(Boolean, nullable=False, default=False)

    status = Column(
        Enum("normal", "deleted"), nullable=False, default="normal"
    )

    created_at = Column(DateTime, server_default=func.now())

    # relationships
    course = relationship("Course", backref="messages")
    sender = relationship("User", foreign_keys=[sender_id], backref="sent_messages")
    recipient = relationship("User", foreign_keys=[recipient_id], backref="received_messages")


class Attendance(Base):
    __tablename__ = "attendances"

    id = Column(BigInteger, primary_key=True, autoincrement=True)
    uuid = Column(
        String(36), unique=True, nullable=False, default=lambda: str(uuid.uuid4())
    )

    course_id = Column(BigInteger, ForeignKey("courses.id"), nullable=False)
    created_by = Column(BigInteger, ForeignKey("users.id"), nullable=False)

    title = Column(String(255), nullable=False)

    status = Column(
        Enum("open", "closed"), nullable=False, default="open"
    )

    created_at = Column(DateTime, server_default=func.now())
    closed_at = Column(DateTime, nullable=True)

    # relationships
    course = relationship("Course", backref="attendances")
    creator = relationship("User", backref="created_attendances")
    records = relationship("AttendanceRecord", back_populates="attendance")


class AttendanceRecord(Base):
    __tablename__ = "attendance_records"

    id = Column(BigInteger, primary_key=True, autoincrement=True)

    attendance_id = Column(BigInteger, ForeignKey("attendances.id"), nullable=False)
    student_id = Column(BigInteger, ForeignKey("users.id"), nullable=False)

    status = Column(
        Enum("present", "absent", "late", "leave"),
        nullable=False,
        default="present",
    )
    note = Column(Text, nullable=True)

    created_at = Column(DateTime, server_default=func.now())

    __table_args__ = (
        UniqueConstraint("attendance_id", "student_id", name="uk_attendance_student"),
    )

    # relationships
    attendance = relationship("Attendance", back_populates="records")
    student = relationship("User", backref="attendance_records")


class PlayRecord(Base):
    __tablename__ = "play_records"

    id = Column(BigInteger, primary_key=True, autoincrement=True)

    user_id = Column(BigInteger, ForeignKey("users.id"), nullable=False)
    video_id = Column(BigInteger, ForeignKey("videos.id"), nullable=False)

    progress = Column(Integer, nullable=False, default=0)
    completed = Column(Boolean, nullable=False, default=False)

    last_played_at = Column(
        DateTime, server_default=func.now(), onupdate=func.now()
    )

    __table_args__ = (
        UniqueConstraint("user_id", "video_id", name="uk_user_video"),
    )

    # relationships
    user = relationship("User", back_populates="play_records")
    video = relationship("Video", back_populates="play_records")
