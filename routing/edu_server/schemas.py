from typing import Optional
from pydantic import BaseModel


class UserCreate(BaseModel):
    username: str
    password: str
    role: str = "student"


class UserLogin(BaseModel):
    username: str
    password: str


class UserOut(BaseModel):
    uuid: str
    username: str
    role: str

    model_config = {"from_attributes": True}


class TokenOut(BaseModel):
    access_token: str
    token_type: str = "bearer"


class CourseCreate(BaseModel):
    name: str
    description: Optional[str] = None


class CourseOut(BaseModel):
    uuid: str
    name: str
    description: Optional[str] = None
    status: str

    model_config = {"from_attributes": True}


class VideoCreate(BaseModel):
    course_uuid: str
    title: str
    description: Optional[str] = None
    file_path: str
    cover_path: Optional[str] = None
    duration: int = 0
    file_size: int = 0


class VideoOut(BaseModel):
    uuid: str
    title: str
    description: Optional[str] = None
    file_path: str
    cover_path: Optional[str] = None
    duration: int
    file_size: int
    status: str

    model_config = {"from_attributes": True}


class PlayRecordUpdate(BaseModel):
    video_uuid: str
    progress: int
    completed: bool = False


class PlayRecordOut(BaseModel):
    progress: int
    completed: bool

    model_config = {"from_attributes": True}
