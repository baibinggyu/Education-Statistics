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
    student_no: Optional[str] = Field(default=None, min_length=1, max_length=64)
    real_name: Optional[str] = Field(default=None, min_length=1, max_length=64)


class UserLogin(BaseModel):
    username: str
    password: str


class TokenOut(BaseModel):
    access_token: str
    token_type: str = "bearer"


# ============================================================
# AI
# ============================================================

class AIMessage(BaseModel):
    role: str = Field(pattern="^(system|user|assistant)$")
    content: str = Field(min_length=1, max_length=8000)


class AIChatRequest(BaseModel):
    messages: list[AIMessage] = Field(min_length=1, max_length=40)


class AIChatResponse(BaseModel):
    content: str
    model: str


class LearningReportRequest(BaseModel):
    learning_data: str = Field(..., min_length=1, max_length=50000)


class StudentAnalysisRequest(BaseModel):
    student_data: str = Field(..., min_length=1, max_length=50000)


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


class StudentBindWithUuid(StudentBind):
    user_uuid: str


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
# Announcement
# ============================================================

class AnnouncementCreate(BaseModel):
    title: str = Field(min_length=1, max_length=255)
    content: str = Field(min_length=1)
    ann_type: str = Field(default="课程通知", pattern="^(课程通知|作业提醒|考试安排|资料更新|其他)$")
    pinned: bool = False
    notify: bool = True


class AnnouncementUpdate(BaseModel):
    title: Optional[str] = Field(default=None, min_length=1, max_length=255)
    content: Optional[str] = None
    ann_type: Optional[str] = Field(default=None, pattern="^(课程通知|作业提醒|考试安排|资料更新|其他)$")
    pinned: Optional[bool] = None
    notify: Optional[bool] = None


class AuthorBriefOut(BaseModel):
    uuid: str
    username: str

    model_config = {"from_attributes": True}


class AnnouncementOut(BaseModel):
    uuid: str
    course_uuid: str
    title: str
    content: str
    ann_type: str
    pinned: bool
    notify: bool
    author: Optional[AuthorBriefOut] = None
    created_at: datetime
    updated_at: Optional[datetime] = None

    model_config = {"from_attributes": True}


# ============================================================
# Message
# ============================================================

class MessageCreate(BaseModel):
    subject: Optional[str] = Field(default=None, max_length=255)
    content: str = Field(min_length=1)
    msg_type: str = Field(default="其他", pattern="^(学习提醒|作业通知|考试安排|课堂反馈|其他)$")
    recipient_username: Optional[str] = None  # None = send to all course members


class MessageOut(BaseModel):
    uuid: str
    course_uuid: str
    subject: Optional[str] = None
    content: str
    msg_type: str
    is_read: bool
    sender: Optional[AuthorBriefOut] = None
    recipient: Optional[AuthorBriefOut] = None
    created_at: datetime

    model_config = {"from_attributes": True}


# ============================================================
# File Upload
# ============================================================

class FileUploadOut(BaseModel):
    file_path: str
    file_size: int
    original_name: str


# ============================================================
# Batch Student Import
# ============================================================

class StudentImportItem(BaseModel):
    username: str = Field(min_length=1, max_length=64)
    password: str = Field(min_length=1, max_length=128)
    student_no: str = Field(min_length=1, max_length=64)
    real_name: str = Field(min_length=1, max_length=64)


class StudentImportResult(BaseModel):
    total: int
    created: int
    skipped: int
    errors: list[str] = []


# ============================================================
# Attendance
# ============================================================

class AttendanceCreate(BaseModel):
    title: str = Field(min_length=1, max_length=255)
    mode: str = Field(default="simple", pattern="^(simple|photo)$")


class AttendanceMark(BaseModel):
    student_uuid: str
    status: str = Field(pattern="^(present|absent|late|leave)$")
    note: Optional[str] = Field(default=None, max_length=500)


class AttendanceRecordOut(BaseModel):
    student_uuid: str
    student_name: str
    student_no: Optional[str] = None
    real_name: Optional[str] = None
    status: str
    note: Optional[str] = None
    has_photo: bool = False
    photo_url: Optional[str] = None
    created_at: datetime

    model_config = {"from_attributes": True}


class AttendanceOut(BaseModel):
    uuid: str
    course_uuid: str
    title: str
    mode: str = "simple"
    status: str
    created_by_name: str
    total: int
    present_count: int
    absent_count: int
    late_count: int
    leave_count: int
    created_at: datetime
    closed_at: Optional[datetime] = None

    model_config = {"from_attributes": True}


class AttendanceDetailOut(BaseModel):
    uuid: str
    course_uuid: str
    title: str
    mode: str = "simple"
    status: str
    created_by_name: str
    total: int
    present_count: int
    absent_count: int
    late_count: int
    leave_count: int
    records: list[AttendanceRecordOut] = []
    created_at: datetime
    closed_at: Optional[datetime] = None

    model_config = {"from_attributes": True}


# ============================================================
# Resource
# ============================================================

class ResourceCreate(BaseModel):
    title: str = Field(min_length=1, max_length=255)
    description: Optional[str] = None
    file_path: str
    file_name: str = Field(min_length=1, max_length=255)
    file_size: int = Field(default=0, ge=0)
    file_type: str = Field(default="other", max_length=64)


class ResourceOut(BaseModel):
    uuid: str
    course_uuid: str
    title: str
    description: Optional[str] = None
    file_name: str
    file_size: int
    file_type: str
    uploader: Optional[AuthorBriefOut] = None
    created_at: datetime

    model_config = {"from_attributes": True}


# ============================================================
# Assignment
# ============================================================

class AssignmentCreate(BaseModel):
    title: str = Field(min_length=1, max_length=255)
    description: Optional[str] = None
    due_date: Optional[datetime] = None
    total_points: Optional[float] = Field(default=100.0, ge=0)


class AssignmentUpdate(BaseModel):
    title: Optional[str] = Field(default=None, min_length=1, max_length=255)
    description: Optional[str] = None
    due_date: Optional[datetime] = None
    total_points: Optional[float] = Field(default=None, ge=0)
    status: Optional[str] = Field(default=None, pattern="^(open|closed)$")


class AssignmentOut(BaseModel):
    uuid: str
    course_uuid: str
    title: str
    description: Optional[str] = None
    due_date: Optional[datetime] = None
    total_points: Optional[float] = None
    has_attachment: bool = False
    attachment_name: Optional[str] = None
    status: str
    author: Optional[AuthorBriefOut] = None
    submission_count: int = 0
    created_at: datetime
    updated_at: Optional[datetime] = None

    model_config = {"from_attributes": True}


# ============================================================
# Submission
# ============================================================

class SubmissionGrade(BaseModel):
    score: Optional[float] = Field(default=None, ge=0)
    feedback: Optional[str] = None


class SubmissionOut(BaseModel):
    uuid: str
    assignment_uuid: str
    student_uuid: str
    student_name: str
    student_no: Optional[str] = None
    content: Optional[str] = None
    file_name: Optional[str] = None
    submitted_at: Optional[datetime] = None
    score: Optional[float] = None
    feedback: Optional[str] = None
    status: str
    created_at: datetime
    updated_at: Optional[datetime] = None

    model_config = {"from_attributes": True}


# ============================================================
# Rebuild forward references (Pydantic v2 style)
# ============================================================

UserMeOut.model_rebuild()
CourseDetailOut.model_rebuild()
ScoreMyOut.model_rebuild()
ScoreSummaryOut.model_rebuild()
VideoDetailOut.model_rebuild()
