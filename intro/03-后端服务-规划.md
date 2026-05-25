# Edu Server Development Plan

本文档用于说明 Edu Server 第一阶段后端开发计划。

当前阶段技术栈：

- FastAPI
- SQLAlchemy
- MariaDB
- PyMySQL
- JWT
- bcrypt
- Uvicorn
- Nginx

当前数据库设计采用内部 `BIGINT id` 与外部 `UUID` 分离的方式，客户端 API 使用 UUID，数据库内部关联使用 BIGINT id。核心表包括 users、students、courses、course_members、units、scores、videos、play_records。:contentReference[oaicite:0]{index=0}

---

# 1. 第一阶段目标

第一阶段目标是完成 Edu Server 的基础服务端结构。

需要完成：

- FastAPI 项目结构
- MariaDB 数据库连接
- SQLAlchemy ORM 模型
- Pydantic Schema
- 用户注册
- 用户登录
- JWT Token 生成
- 当前用户身份获取
- 课程基础查询
- 视频基础查询
- 播放记录更新
- Nginx 反向代理部署

---

# 2. 项目目录结构

```txt
edu_server/
├── main.py
├── database.py
├── models.py
├── schemas.py
├── security.py
├── deps.py
├── routers/
│   ├── __init__.py
│   ├── auth.py
│   ├── users.py
│   ├── courses.py
│   ├── videos.py
│   └── play_records.py
├── requirements.txt
└── README.md
```

创建目录：

```bash
mkdir edu_server
cd edu_server

mkdir routers
touch main.py
touch database.py
touch models.py
touch schemas.py
touch security.py
touch deps.py

touch routers/__init__.py
touch routers/auth.py
touch routers/users.py
touch routers/courses.py
touch routers/videos.py
touch routers/play_records.py

touch requirements.txt
```

---

# 3. 安装依赖

## requirements.txt

```txt
fastapi
uvicorn
sqlalchemy
pymysql
python-jose[cryptography]
passlib[bcrypt]
python-multipart
```

安装：

```bash
pip install -r requirements.txt
```

---

# 4. 数据库连接

## database.py

```python
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, declarative_base

DATABASE_URL = "mysql+pymysql://edu_user:你的密码@127.0.0.1:3306/edu_db?charset=utf8mb4"

engine = create_engine(
    DATABASE_URL,
    pool_pre_ping=True,
    pool_recycle=3600,
    echo=False,
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
```

说明：

- `engine` 负责数据库连接池。
- `SessionLocal` 负责创建数据库会话。
- `get_db()` 给 FastAPI 的 `Depends()` 使用。
- 每个请求创建一个 Session，请求结束后关闭。

---

# 5. ORM 模型

## models.py

```python
import uuid

from sqlalchemy import (
    Column,
    BigInteger,
    String,
    Text,
    DateTime,
    ForeignKey,
    Integer,
    Float,
    Boolean,
    Enum,
    UniqueConstraint,
)
from sqlalchemy.sql import func

from database import Base


class User(Base):
    __tablename__ = "users"

    id = Column(BigInteger, primary_key=True, autoincrement=True)
    uuid = Column(String(36), unique=True, nullable=False, default=lambda: str(uuid.uuid4()))

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
    uuid = Column(String(36), unique=True, nullable=False, default=lambda: str(uuid.uuid4()))

    name = Column(String(128), nullable=False)
    description = Column(Text)

    teacher_id = Column(BigInteger, ForeignKey("users.id"), nullable=False)

    status = Column(Enum("normal", "hidden", "deleted"), nullable=False, default="normal")
    created_at = Column(DateTime, server_default=func.now())


class CourseMember(Base):
    __tablename__ = "course_members"

    id = Column(BigInteger, primary_key=True, autoincrement=True)

    course_id = Column(BigInteger, ForeignKey("courses.id"), nullable=False)
    user_id = Column(BigInteger, ForeignKey("users.id"), nullable=False)

    member_role = Column(Enum("student", "teacher", "assistant"), nullable=False)
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
    uuid = Column(String(36), unique=True, nullable=False, default=lambda: str(uuid.uuid4()))

    course_id = Column(BigInteger, ForeignKey("courses.id"), nullable=False)
    uploader_id = Column(BigInteger, ForeignKey("users.id"), nullable=False)

    title = Column(String(255), nullable=False)
    description = Column(Text)

    file_path = Column(String(255), nullable=False)
    cover_path = Column(String(255))

    duration = Column(Integer, nullable=False, default=0)
    file_size = Column(BigInteger, nullable=False, default=0)

    status = Column(Enum("normal", "hidden", "deleted"), nullable=False, default="normal")

    created_at = Column(DateTime, server_default=func.now())
    updated_at = Column(DateTime, server_default=func.now(), onupdate=func.now())


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
```

---

# 6. Pydantic Schema

## schemas.py

```python
from pydantic import BaseModel
from typing import Optional


class UserCreate(BaseModel):
    username: str
    password: str
    role: str


class UserLogin(BaseModel):
    username: str
    password: str


class UserOut(BaseModel):
    uuid: str
    username: str
    role: str

    class Config:
        from_attributes = True


class TokenOut(BaseModel):
    access_token: str
    token_type: str = "bearer"


class CourseCreate(BaseModel):
    name: str
    description: Optional[str] = None


class CourseOut(BaseModel):
    uuid: str
    name: str
    description: Optional[str]
    status: str

    class Config:
        from_attributes = True


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
    description: Optional[str]
    file_path: str
    cover_path: Optional[str]
    duration: int
    file_size: int
    status: str

    class Config:
        from_attributes = True


class PlayRecordUpdate(BaseModel):
    video_uuid: str
    progress: int
    completed: bool = False


class PlayRecordOut(BaseModel):
    progress: int
    completed: bool

    class Config:
        from_attributes = True
```

---

# 7. 密码哈希与 JWT

## security.py

```python
from datetime import datetime, timedelta

from jose import jwt, JWTError
from passlib.context import CryptContext

SECRET_KEY = "请替换成足够长的随机字符串"
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 60 * 24 * 7

pwd_context = CryptContext(
    schemes=["bcrypt"],
    deprecated="auto",
)


def hash_password(password: str) -> str:
    return pwd_context.hash(password)


def verify_password(raw_password: str, hashed_password: str) -> bool:
    return pwd_context.verify(raw_password, hashed_password)


def create_access_token(data: dict) -> str:
    payload = data.copy()

    expire = datetime.utcnow() + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    payload.update({"exp": expire})

    return jwt.encode(payload, SECRET_KEY, algorithm=ALGORITHM)


def decode_access_token(token: str) -> dict:
    return jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
```

JWT Payload 建议：

```json
{
  "sub": "user_uuid",
  "role": "student"
}
```

其中：

- `sub` 保存用户 UUID。
- `role` 保存用户角色。
- 不直接暴露数据库内部 id。

---

# 8. 通用依赖

## deps.py

```python
from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from sqlalchemy.orm import Session
from jose import JWTError

from database import get_db
from models import User
from security import decode_access_token

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/api/auth/login")


def get_current_user(
    token: str = Depends(oauth2_scheme),
    db: Session = Depends(get_db),
) -> User:
    try:
        payload = decode_access_token(token)
        user_uuid = payload.get("sub")

        if user_uuid is None:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid token",
            )

    except JWTError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid token",
        )

    user = db.query(User).filter(User.uuid == user_uuid).first()

    if user is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User not found",
        )

    if user.status != 1:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="User is disabled",
        )

    return user


def require_teacher_or_admin(user: User = Depends(get_current_user)) -> User:
    if user.role not in ("teacher", "admin"):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Permission denied",
        )

    return user


def require_admin(user: User = Depends(get_current_user)) -> User:
    if user.role != "admin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Admin permission required",
        )

    return user
```

---

# 9. 登录与注册接口

## routers/auth.py

```python
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from database import get_db
from models import User
from schemas import UserCreate, UserLogin, TokenOut, UserOut
from security import hash_password, verify_password, create_access_token

router = APIRouter()


@router.post("/register", response_model=UserOut)
def register_user(data: UserCreate, db: Session = Depends(get_db)):
    exists = db.query(User).filter(User.username == data.username).first()

    if exists:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Username already exists",
        )

    if data.role not in ("student", "teacher", "admin"):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid role",
        )

    user = User(
        username=data.username,
        password_hash=hash_password(data.password),
        role=data.role,
    )

    db.add(user)
    db.commit()
    db.refresh(user)

    return user


@router.post("/login", response_model=TokenOut)
def login(data: UserLogin, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.username == data.username).first()

    if user is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid username or password",
        )

    if not verify_password(data.password, user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid username or password",
        )

    token = create_access_token(
        {
            "sub": user.uuid,
            "role": user.role,
        }
    )

    return TokenOut(access_token=token)
```

---

# 10. 用户接口

## routers/users.py

```python
from fastapi import APIRouter, Depends

from models import User
from schemas import UserOut
from deps import get_current_user

router = APIRouter()


@router.get("/me", response_model=UserOut)
def get_me(current_user: User = Depends(get_current_user)):
    return current_user
```

---

# 11. 课程接口

## routers/courses.py

```python
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from database import get_db
from models import Course, CourseMember, User
from schemas import CourseCreate, CourseOut
from deps import get_current_user, require_teacher_or_admin

router = APIRouter()


@router.post("/", response_model=CourseOut)
def create_course(
    data: CourseCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_teacher_or_admin),
):
    course = Course(
        name=data.name,
        description=data.description,
        teacher_id=current_user.id,
    )

    db.add(course)
    db.commit()
    db.refresh(course)

    member = CourseMember(
        course_id=course.id,
        user_id=current_user.id,
        member_role="teacher",
    )

    db.add(member)
    db.commit()

    return course


@router.get("/", response_model=list[CourseOut])
def list_courses(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    courses = (
        db.query(Course)
        .join(CourseMember, CourseMember.course_id == Course.id)
        .filter(CourseMember.user_id == current_user.id)
        .filter(Course.status == "normal")
        .all()
    )

    return courses


@router.get("/{course_uuid}", response_model=CourseOut)
def get_course(
    course_uuid: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    course = (
        db.query(Course)
        .filter(Course.uuid == course_uuid)
        .filter(Course.status == "normal")
        .first()
    )

    if course is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Course not found",
        )

    member = (
        db.query(CourseMember)
        .filter(CourseMember.course_id == course.id)
        .filter(CourseMember.user_id == current_user.id)
        .first()
    )

    if member is None and current_user.role != "admin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Permission denied",
        )

    return course
```

---

# 12. 视频接口

## routers/videos.py

```python
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from database import get_db
from models import Video, Course, CourseMember, User
from schemas import VideoCreate, VideoOut
from deps import get_current_user, require_teacher_or_admin

router = APIRouter()


def check_course_access(db: Session, course_id: int, user: User) -> bool:
    if user.role == "admin":
        return True

    member = (
        db.query(CourseMember)
        .filter(CourseMember.course_id == course_id)
        .filter(CourseMember.user_id == user.id)
        .first()
    )

    return member is not None


@router.post("/", response_model=VideoOut)
def create_video(
    data: VideoCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_teacher_or_admin),
):
    course = (
        db.query(Course)
        .filter(Course.uuid == data.course_uuid)
        .filter(Course.status == "normal")
        .first()
    )

    if course is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Course not found",
        )

    if current_user.role != "admin" and course.teacher_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Permission denied",
        )

    video = Video(
        course_id=course.id,
        uploader_id=current_user.id,
        title=data.title,
        description=data.description,
        file_path=data.file_path,
        cover_path=data.cover_path,
        duration=data.duration,
        file_size=data.file_size,
    )

    db.add(video)
    db.commit()
    db.refresh(video)

    return video


@router.get("/course/{course_uuid}", response_model=list[VideoOut])
def list_course_videos(
    course_uuid: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    course = (
        db.query(Course)
        .filter(Course.uuid == course_uuid)
        .filter(Course.status == "normal")
        .first()
    )

    if course is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Course not found",
        )

    if not check_course_access(db, course.id, current_user):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Permission denied",
        )

    videos = (
        db.query(Video)
        .filter(Video.course_id == course.id)
        .filter(Video.status == "normal")
        .all()
    )

    return videos


@router.get("/{video_uuid}", response_model=VideoOut)
def get_video(
    video_uuid: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    video = (
        db.query(Video)
        .filter(Video.uuid == video_uuid)
        .filter(Video.status == "normal")
        .first()
    )

    if video is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Video not found",
        )

    if not check_course_access(db, video.course_id, current_user):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Permission denied",
        )

    return video
```

---

# 13. 播放记录接口

## routers/play_records.py

```python
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from database import get_db
from models import Video, PlayRecord, CourseMember, User
from schemas import PlayRecordUpdate, PlayRecordOut
from deps import get_current_user

router = APIRouter()


def check_course_access(db: Session, course_id: int, user: User) -> bool:
    if user.role == "admin":
        return True

    member = (
        db.query(CourseMember)
        .filter(CourseMember.course_id == course_id)
        .filter(CourseMember.user_id == user.id)
        .first()
    )

    return member is not None


@router.post("/update", response_model=PlayRecordOut)
def update_play_record(
    data: PlayRecordUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    video = (
        db.query(Video)
        .filter(Video.uuid == data.video_uuid)
        .filter(Video.status == "normal")
        .first()
    )

    if video is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Video not found",
        )

    if not check_course_access(db, video.course_id, current_user):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Permission denied",
        )

    record = (
        db.query(PlayRecord)
        .filter(PlayRecord.user_id == current_user.id)
        .filter(PlayRecord.video_id == video.id)
        .first()
    )

    if record is None:
        record = PlayRecord(
            user_id=current_user.id,
            video_id=video.id,
            progress=data.progress,
            completed=data.completed,
        )
        db.add(record)
    else:
        record.progress = data.progress
        record.completed = data.completed

    db.commit()
    db.refresh(record)

    return record


@router.get("/{video_uuid}", response_model=PlayRecordOut)
def get_play_record(
    video_uuid: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    video = (
        db.query(Video)
        .filter(Video.uuid == video_uuid)
        .filter(Video.status == "normal")
        .first()
    )

    if video is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Video not found",
        )

    record = (
        db.query(PlayRecord)
        .filter(PlayRecord.user_id == current_user.id)
        .filter(PlayRecord.video_id == video.id)
        .first()
    )

    if record is None:
        return PlayRecordOut(progress=0, completed=False)

    return record
```

---

# 14. FastAPI 入口

## main.py

```python
from fastapi import FastAPI

from database import Base, engine
from routers import auth, users, courses, videos, play_records

Base.metadata.create_all(bind=engine)

app = FastAPI(
    title="Edu Server",
    version="0.1.0",
)

app.include_router(auth.router, prefix="/api/auth", tags=["auth"])
app.include_router(users.router, prefix="/api/users", tags=["users"])
app.include_router(courses.router, prefix="/api/courses", tags=["courses"])
app.include_router(videos.router, prefix="/api/videos", tags=["videos"])
app.include_router(play_records.router, prefix="/api/play-records", tags=["play_records"])


@app.get("/")
def root():
    return {
        "name": "Edu Server",
        "status": "running",
    }
```

---

# 15. 启动服务

开发启动：

```bash
uvicorn main:app --host 127.0.0.1 --port 55555 --reload
```

服务器启动：

```bash
uvicorn main:app --host 127.0.0.1 --port 55555
```

访问：

```txt
http://127.0.0.1:55555/docs
```

FastAPI 会自动生成接口文档。

---

# 16. Nginx 反向代理

## nginx 配置示例

```nginx
server {
    listen 80;
    server_name your_domain_or_ip;

    location /api/ {
        proxy_pass http://127.0.0.1:55555/api/;

        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }

    location /docs {
        proxy_pass http://127.0.0.1:55555/docs;
    }

    location /openapi.json {
        proxy_pass http://127.0.0.1:55555/openapi.json;
    }
}
```

检查配置：

```bash
sudo nginx -t
```

重启 Nginx：

```bash
sudo systemctl reload nginx
```

---

# 17. 第一阶段测试顺序

## 17.1 注册用户

```bash
curl -X POST http://127.0.0.1:55555/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "username": "teacher1",
    "password": "123456",
    "role": "teacher"
  }'
```

## 17.2 登录

```bash
curl -X POST http://127.0.0.1:55555/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "username": "teacher1",
    "password": "123456"
  }'
```

返回：

```json
{
  "access_token": "...",
  "token_type": "bearer"
}
```

## 17.3 获取当前用户

```bash
curl http://127.0.0.1:55555/api/users/me \
  -H "Authorization: Bearer 你的token"
```

## 17.4 创建课程

```bash
curl -X POST http://127.0.0.1:55555/api/courses/ \
  -H "Authorization: Bearer 你的token" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "C++ 程序设计",
    "description": "C++ 基础课程"
  }'
```

## 17.5 创建视频

```bash
curl -X POST http://127.0.0.1:55555/api/videos/ \
  -H "Authorization: Bearer 你的token" \
  -H "Content-Type: application/json" \
  -d '{
    "course_uuid": "课程uuid",
    "title": "第一节：环境配置",
    "description": "C++ 开发环境配置",
    "file_path": "/uploads/videos/cpp_001.mp4",
    "cover_path": "/uploads/covers/cpp_001.jpg",
    "duration": 1200,
    "file_size": 104857600
  }'
```

## 17.6 查询课程视频

```bash
curl http://127.0.0.1:55555/api/videos/course/课程uuid \
  -H "Authorization: Bearer 你的token"
```

## 17.7 更新播放记录

```bash
curl -X POST http://127.0.0.1:55555/api/play-records/update \
  -H "Authorization: Bearer 你的token" \
  -H "Content-Type: application/json" \
  -d '{
    "video_uuid": "视频uuid",
    "progress": 300,
    "completed": false
  }'
```

---

# 18. 当前阶段注意事项

## 18.1 不直接暴露数据库 id

接口中不要使用：

```txt
/api/videos/1
```

应该使用：

```txt
/api/videos/{uuid}
```

## 18.2 密码不保存明文

注册时必须保存：

```txt
password_hash
```

不能保存：

```txt
password
```

## 18.3 FastAPI 不监听公网

推荐：

```bash
uvicorn main:app --host 127.0.0.1 --port 55555
```

不推荐第一阶段直接：

```bash
uvicorn main:app --host 0.0.0.0 --port 55555
```

公网入口由 Nginx 负责。

## 18.4 删除优先使用逻辑删除

课程、视频等数据优先使用：

```txt
status = deleted
```

而不是直接删除数据库记录。

原因：

- 保留成绩关联
- 保留播放记录关联
- 避免历史数据断裂

---

# 19. 第一阶段完成标准

第一阶段完成后，需要满足：

- 服务可以启动
- MariaDB 可以连接
- ORM 表结构可以创建
- 用户可以注册
- 用户可以登录
- 登录后可以拿到 JWT
- JWT 可以访问 `/api/users/me`
- 教师可以创建课程
- 教师可以创建视频
- 用户可以查询自己课程下的视频
- 用户可以更新视频播放进度
- Nginx 可以正常反向代理到 FastAPI

完成这些后，Edu Server 第一版后端基础结构成立。
