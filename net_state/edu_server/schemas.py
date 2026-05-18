from datetime import datetime
from typing import Optional

from pydantic import BaseModel, Field


# ============================================================
# Auth
# ============================================================

class UserCreate(BaseModel):
    username: str = Field(min_length=1, max_length=64)
    password: str = Field(min_length=1, max_length=128)
    role: str = Field(default="student", pattern="^(student|teacher|admin)$")


class UserLogin(BaseModel):
    username: str
    password: str


class TokenOut(BaseModel):
    access_token: str
    token_type: str = "bearer"


# ============================================================
# User
# ============================================================

class UserOut(BaseModel):
    uuid: str
    username: str
    role: str
    created_at: datetime

    model_config = {"from_attributes": True}


class UserMeOut(BaseModel):
    uuid: str
    username: str
    role: str
    created_at: datetime
    student: Optional["StudentBriefOut"] = None

    model_config = {"from_attributes": True}


class UserUpdate(BaseModel):
    username: Optional[str] = Field(default=None, min_length=1, max_length=64)


class UserStatusUpdate(BaseModel):
    status: int = Field(ge=0, le=1)


class UserPageOut(BaseModel):
    items: list[UserOut]
    total: int
    page: int
    size: int


# ============================================================
# Student
# ============================================================

class StudentBind(BaseModel):
    student_no: str = Field(min_length=1, max_length=64)
    real_name: str = Field(min_length=1, max_length=64)


class StudentBriefOut(BaseModel):
    student_no: str
    real_name: str

    model_config = {"from_attributes": True}


class StudentOut(BaseModel):
    user_uuid: str
    student_no: str
    real_name: str
    course_count: int = 0
    video_completed_count: int = 0

    model_config = {"from_attributes": True}


# ============================================================
# Course
# ============================================================

class CourseCreate(BaseModel):
    name: str = Field(min_length=1, max_length=128)
    description: Optional[str] = None


class CourseUpdate(BaseModel):
    name: Optional[str] = Field(default=None, min_length=1, max_length=128)
    description: Optional[str] = None


class TeacherBriefOut(BaseModel):
    uuid: str
    username: str

    model_config = {"from_attributes": True}


class CourseOut(BaseModel):
    uuid: str
    name: str
    description: Optional[str] = None
    teacher: Optional[TeacherBriefOut] = None
    status: str
    member_count: int = 0
    video_count: int = 0
    created_at: datetime

    model_config = {"from_attributes": True}


class CourseMyOut(BaseModel):
    uuid: str
    name: str
    description: Optional[str] = None
    teacher: Optional[TeacherBriefOut] = None
    status: str
    member_count: int = 0
    video_count: int = 0
    my_role: str
    created_at: datetime

    model_config = {"from_attributes": True}


class CourseDetailOut(BaseModel):
    uuid: str
    name: str
    description: Optional[str] = None
    teacher: Optional[TeacherBriefOut] = None
    status: str
    units: list["UnitOut"] = []
    member_count: int = 0
    created_at: datetime

    model_config = {"from_attributes": True}


# ============================================================
# Course Member
# ============================================================

class CourseMemberAdd(BaseModel):
    username: Optional[str] = None
    student_no: Optional[str] = None


class MemberStudentOut(BaseModel):
    student_no: str
    real_name: str

    model_config = {"from_attributes": True}


class CourseMemberOut(BaseModel):
    user_uuid: str
    username: str
    member_role: str
    joined_at: datetime
    student: Optional[MemberStudentOut] = None

    model_config = {"from_attributes": True}


# ============================================================
# Unit
# ============================================================

class UnitCreate(BaseModel):
    name: str = Field(min_length=1, max_length=128)
    weight: float = Field(default=0, ge=0)
    full_score: float = Field(default=100, gt=0)
    unit_order: int = Field(default=0, ge=0)


class UnitUpdate(BaseModel):
    name: Optional[str] = Field(default=None, min_length=1, max_length=128)
    weight: Optional[float] = Field(default=None, ge=0)
    full_score: Optional[float] = Field(default=None, gt=0)
    unit_order: Optional[int] = Field(default=None, ge=0)


class UnitOut(BaseModel):
    id: int
    name: str
    weight: float
    full_score: float
    unit_order: int
    created_at: datetime

    model_config = {"from_attributes": True}


class UnitReorderItem(BaseModel):
    unit_id: int
    unit_order: int


# ============================================================
# Score
# ============================================================

class ScoreCreate(BaseModel):
    course_uuid: str
    student_uuid: str
    unit_id: int
    score: float


class ScoreBatchCreate(BaseModel):
    course_uuid: str
    unit_id: int
    scores: list["ScoreEntry"]


class ScoreEntry(BaseModel):
    student_uuid: str
    score: float


class ScoreSingleOut(BaseModel):
    student_uuid: str
    student_no: str
    real_name: str
    course_uuid: str
    unit_id: int
    unit_name: str
    score: float
    updated_at: datetime

    model_config = {"from_attributes": True}


class ScoreMyOut(BaseModel):
    course_name: str
    units: list[UnitOut]
    my_scores: list["MyScoreItem"]
    weighted_total: Optional[float] = None
    rank: Optional[int] = None


class MyScoreItem(BaseModel):
    unit_id: int
    score: Optional[float] = None


class ScoreSummaryStudent(BaseModel):
    student_uuid: str
    student_no: str
    real_name: str
    scores: list[Optional[float]]
    weighted_total: Optional[float] = None
    rank: Optional[int] = None


class ScoreSummaryOut(BaseModel):
    course_name: str
    unit_names: list[str]
    unit_weights: list[float]
    students: list[ScoreSummaryStudent]


class ScoreBand(BaseModel):
    range: str
    count: int


class ScoreDistributionOut(BaseModel):
    bands: list[ScoreBand]
    total: int
    average: float
    median: float
    passed: int
    failed: int


# ============================================================
# Video
# ============================================================

class VideoCreate(BaseModel):
    course_uuid: str
    title: str = Field(min_length=1, max_length=255)
    description: Optional[str] = None
    file_path: str
    cover_path: Optional[str] = None
    duration: int = Field(default=0, ge=0)
    file_size: int = Field(default=0, ge=0)


class VideoUpdate(BaseModel):
    title: Optional[str] = Field(default=None, min_length=1, max_length=255)
    description: Optional[str] = None
    status: Optional[str] = Field(default=None, pattern="^(normal|hidden|deleted)$")


class PlayProgressOut(BaseModel):
    progress: int
    completed: bool

    model_config = {"from_attributes": True}


class VideoOut(BaseModel):
    uuid: str
    title: str
    description: Optional[str] = None
    course_uuid: str
    course_name: Optional[str] = None
    duration: int
    file_size: int
    has_cover: bool = False
    status: str
    created_at: datetime

    model_config = {"from_attributes": True}


class VideoDetailOut(BaseModel):
    uuid: str
    title: str
    description: Optional[str] = None
    course_uuid: str
    course_name: Optional[str] = None
    uploader: Optional[TeacherBriefOut] = None
    duration: int
    file_size: int
    cover_url: Optional[str] = None
    status: str
    my_progress: Optional[PlayProgressOut] = None
    created_at: datetime

    model_config = {"from_attributes": True}


# ============================================================
# Play Record
# ============================================================

class PlayRecordUpdate(BaseModel):
    video_uuid: str
    progress: int = Field(ge=0)
    completed: bool = False


class PlayRecordOut(BaseModel):
    video_uuid: Optional[str] = None
    progress: int
    completed: bool
    last_played_at: Optional[datetime] = None

    model_config = {"from_attributes": True}


class PlayRecordCourseOut(BaseModel):
    video_uuid: str
    video_title: str
    progress: int
    duration: int
    completed: bool
    last_played_at: Optional[datetime] = None


# ============================================================
# File Upload
# ============================================================

class FileUploadOut(BaseModel):
    file_path: str
    file_size: int
    original_name: str


# ============================================================
# Rebuild forward references (Pydantic v2 style)
# ============================================================

UserMeOut.model_rebuild()
CourseDetailOut.model_rebuild()
ScoreMyOut.model_rebuild()
ScoreSummaryOut.model_rebuild()
VideoDetailOut.model_rebuild()
