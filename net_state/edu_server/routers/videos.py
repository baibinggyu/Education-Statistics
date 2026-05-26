"""视频管理路由。

视频元数据 CRUD + 流媒体播放（X-Accel-Redirect 模式）。
"""

import os
import subprocess
import tempfile
from datetime import datetime, timezone
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query, status
from fastapi.responses import FileResponse, Response
from jose import JWTError
from sqlalchemy.orm import Session

from database import get_db
from deps import get_current_user, require_teacher_or_admin
from security import decode_access_token
from models import Course, CourseMember, PlayRecord, User, Video
from schemas import (
    PlayProgressOut,
    TeacherBriefOut,
    VideoCreate,
    VideoDetailOut,
    VideoOut,
    VideoUpdate,
)

router = APIRouter()

VIDEO_SERVE_DIR = "/srv/edu/uploads/videos"

_VIDEO_MIME = {
    ".mp4": "video/mp4",
    ".webm": "video/webm",
    ".mkv": "video/x-matroska",
    ".avi": "video/x-msvideo",
    ".mov": "video/quicktime",
}


# ============================================================
# 辅助函数
# ============================================================

def _get_course_or_404(course_uuid: str, db: Session) -> Course:
    course = (
        db.query(Course)
        .filter(Course.uuid == course_uuid, Course.status != "deleted")
        .first()
    )
    if course is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Course not found")
    return course


def _require_course_teacher_or_admin(course: Course, user: User):
    if user.role != "admin" and course.teacher_id != user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only the course teacher can perform this action",
        )


def _check_course_access(course_id: int, user: User, db: Session) -> bool:
    if user.role == "admin":
        return True
    member = (
        db.query(CourseMember)
        .filter(CourseMember.course_id == course_id, CourseMember.user_id == user.id)
        .first()
    )
    return member is not None


# ============================================================
# 视频 CRUD
# ============================================================

@router.post("/", response_model=VideoOut, status_code=status.HTTP_201_CREATED)
def create_video(
    data: VideoCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_teacher_or_admin),
):
    course = _get_course_or_404(data.course_uuid, db)
    _require_course_teacher_or_admin(course, current_user)

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

    return VideoOut(
        uuid=video.uuid,
        title=video.title,
        description=video.description,
        course_uuid=course.uuid,
        course_name=course.name,
        duration=video.duration,
        file_size=video.file_size,
        has_cover=bool(video.cover_path),
        status=video.status,
        created_at=video.created_at,
    )


@router.get("/course/{course_uuid}", response_model=list[VideoOut])
def list_course_videos(
    course_uuid: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    course = _get_course_or_404(course_uuid, db)
    if not _check_course_access(course.id, current_user, db):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Permission denied")

    videos = (
        db.query(Video)
        .filter(Video.course_id == course.id, Video.status == "normal")
        .all()
    )
    return [
        VideoOut(
            uuid=v.uuid,
            title=v.title,
            description=v.description,
            course_uuid=course.uuid,
            course_name=course.name,
            duration=v.duration,
            file_size=v.file_size,
            has_cover=bool(v.cover_path),
            status=v.status,
            created_at=v.created_at,
        )
        for v in videos
    ]


@router.get("/{video_uuid}", response_model=VideoDetailOut)
def get_video(
    video_uuid: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    video = (
        db.query(Video)
        .filter(Video.uuid == video_uuid, Video.status != "deleted")
        .first()
    )
    if video is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Video not found")

    if not _check_course_access(video.course_id, current_user, db):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Permission denied")

    uploader = video.uploader
    record = (
        db.query(PlayRecord)
        .filter(PlayRecord.user_id == current_user.id, PlayRecord.video_id == video.id)
        .first()
    )

    return VideoDetailOut(
        uuid=video.uuid,
        title=video.title,
        description=video.description,
        course_uuid=video.course.uuid,
        course_name=video.course.name,
        uploader=TeacherBriefOut.model_validate(uploader) if uploader else None,
        duration=video.duration,
        file_size=video.file_size,
        cover_url=f"/api/files/cover/{video.uuid}" if video.cover_path else None,
        status=video.status,
        my_progress=PlayProgressOut.model_validate(record) if record else None,
        created_at=video.created_at,
    )


@router.patch("/{video_uuid}", response_model=VideoOut)
def update_video(
    video_uuid: str,
    data: VideoUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    video = (
        db.query(Video)
        .filter(Video.uuid == video_uuid, Video.status != "deleted")
        .first()
    )
    if video is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Video not found")

    course = db.query(Course).filter(Course.id == video.course_id).first()
    _require_course_teacher_or_admin(course, current_user)

    if data.title is not None:
        video.title = data.title
    if data.description is not None:
        video.description = data.description
    if data.status is not None:
        video.status = data.status

    db.commit()
    db.refresh(video)

    return VideoOut(
        uuid=video.uuid,
        title=video.title,
        description=video.description,
        course_uuid=course.uuid,
        course_name=course.name,
        duration=video.duration,
        file_size=video.file_size,
        has_cover=bool(video.cover_path),
        status=video.status,
        created_at=video.created_at,
    )


@router.delete("/{video_uuid}", status_code=status.HTTP_204_NO_CONTENT)
def delete_video(
    video_uuid: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    video = (
        db.query(Video)
        .filter(Video.uuid == video_uuid, Video.status != "deleted")
        .first()
    )
    if video is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Video not found")

    course = db.query(Course).filter(Course.id == video.course_id).first()
    _require_course_teacher_or_admin(course, current_user)

    video.status = "deleted"
    db.commit()


# ============================================================
# 视频流媒体
# ============================================================

@router.get("/{video_uuid}/stream")
def stream_video(
    video_uuid: str,
    token: Optional[str] = Query(default=None),
    db: Session = Depends(get_db),
):
    """鉴权后返回视频流。

    支持两种认证方式：
    1. ?token=<jwt> 查询参数（给 QMediaPlayer 等不支持自定义头的播放器）
    2. Authorization: Bearer <token> 头（标准 JWT）

    生产环境: 设置 X-Accel-Redirect 头，让 Nginx 直接发送文件。
    开发环境: 直接使用 FileResponse 发送文件（小文件场景）。
    """
    user = None
    if token:
        try:
            payload = decode_access_token(token)
            user_uuid = payload.get("sub")
            if user_uuid:
                user = db.query(User).filter(User.uuid == user_uuid, User.status == 1).first()
        except JWTError:
            pass

    if user is None:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid or missing token")

    video = (
        db.query(Video)
        .filter(Video.uuid == video_uuid, Video.status == "normal")
        .first()
    )
    if video is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Video not found")

    if not _check_course_access(video.course_id, user, db):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Permission denied")

    file_path = video.file_path

    # 尝试 X-Accel-Redirect（生产环境 Nginx internal location）
    # Nginx 如果未配置 /internal/video/，会忽略此头
    accel_path = None
    if file_path.startswith(VIDEO_SERVE_DIR):
        accel_path = "/internal/video" + file_path[len(VIDEO_SERVE_DIR):]
    else:
        accel_path = f"/internal/video/{os.path.basename(file_path)}"

    if os.path.isfile(file_path):
        response = Response()
        response.headers["X-Accel-Redirect"] = accel_path
        response.headers["Accept-Ranges"] = "bytes"
        return response

    raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Video file not found on disk")


# ============================================================
# 视频下载（可选水印）
# ============================================================

@router.get("/{video_uuid}/download")
def download_video(
    video_uuid: str,
    watermark: bool = Query(default=False),
    token: Optional[str] = Query(default=None),
    db: Session = Depends(get_db),
):
    """下载视频文件，可选烧录用户信息水印。

    水印内容: 用户名 + 下载时间，通过 ffmpeg drawtext 滤镜烧录到视频左上角。
    """
    user = None
    if token:
        try:
            payload = decode_access_token(token)
            user_uuid_val = payload.get("sub")
            if user_uuid_val:
                user = db.query(User).filter(User.uuid == user_uuid_val, User.status == 1).first()
        except JWTError:
            pass

    if user is None:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid or missing token")

    video = (
        db.query(Video)
        .filter(Video.uuid == video_uuid, Video.status == "normal")
        .first()
    )
    if video is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Video not found")

    if not _check_course_access(video.course_id, user, db):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Permission denied")

    file_path = video.file_path
    if not os.path.isfile(file_path):
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Video file not found on disk")

    if not watermark:
        ext = os.path.splitext(file_path)[1]
        media_type = _VIDEO_MIME.get(ext, "application/octet-stream")
        return FileResponse(
            file_path,
            media_type=media_type,
            filename=video.title + ext,
            headers={"Content-Disposition": f'attachment; filename="{video.title}{ext}"'},
        )

    # 水印模式: 使用 ffmpeg 烧录文本
    now_str = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S UTC")
    watermark_text = f"User: {user.username} | Time: {now_str}"

    suffix = os.path.splitext(file_path)[1] or ".mp4"
    with tempfile.NamedTemporaryFile(suffix=suffix, delete=False) as tmp:
        tmp_path = tmp.name

    try:
        cmd = [
            "ffmpeg", "-y",
            "-i", file_path,
            "-vf", (
                f"drawtext=text='{watermark_text}':"
                f"fontcolor=white@0.7:fontsize=20:"
                f"box=1:boxcolor=black@0.4:"
                f"x=10:y=10"
            ),
            "-c:a", "copy",
            "-movflags", "+faststart",
            tmp_path,
        ]
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=300)
        if result.returncode != 0:
            os.unlink(tmp_path)
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail=f"Watermark processing failed",
            )

        ext = os.path.splitext(file_path)[1]
        media_type = _VIDEO_MIME.get(ext, "application/octet-stream")
        download_name = f"{video.title}_watermarked{ext}"

        # 使用后台线程清理临时文件
        import threading

        def _cleanup():
            try:
                os.unlink(tmp_path)
            except OSError:
                pass

        response = FileResponse(
            tmp_path,
            media_type=media_type,
            filename=download_name,
            headers={"Content-Disposition": f'attachment; filename="{download_name}"'},
        )
        response.background = _cleanup
        return response

    except subprocess.TimeoutExpired:
        os.unlink(tmp_path)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Watermark processing timed out",
        )
    except Exception:
        os.unlink(tmp_path)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Download failed",
        )
