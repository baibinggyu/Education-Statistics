"""文件上传路由。

视频文件和封面图片上传。
"""

import os
import uuid

from fastapi import APIRouter, Depends, HTTPException, UploadFile, status
from sqlalchemy.orm import Session

from database import get_db
from deps import get_current_user, require_teacher_or_admin
from models import Course, User
from schemas import FileUploadOut

router = APIRouter()

# 上传目录
UPLOAD_VIDEO_DIR = "/srv/edu/uploads/videos"
UPLOAD_COVER_DIR = "/srv/edu/uploads/covers"

# 允许的视频类型
ALLOWED_VIDEO_EXTENSIONS = {".mp4", ".avi", ".mov", ".mkv", ".webm", ".flv"}
ALLOWED_VIDEO_MIMES = {
    "video/mp4",
    "video/x-msvideo",
    "video/quicktime",
    "video/x-matroska",
    "video/webm",
    "video/x-flv",
}
# 允许的图片类型
ALLOWED_COVER_EXTENSIONS = {".jpg", ".jpeg", ".png", ".webp"}
ALLOWED_COVER_MIMES = {"image/jpeg", "image/png", "image/webp"}
# 文件大小限制
MAX_VIDEO_SIZE = 500 * 1024 * 1024  # 500 MB
MAX_COVER_SIZE = 10 * 1024 * 1024  # 10 MB


def _ensure_dir(path: str):
    os.makedirs(path, exist_ok=True)


@router.post("/upload/video", response_model=FileUploadOut, status_code=status.HTTP_201_CREATED)
async def upload_video(
    file: UploadFile,
    course_uuid: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_teacher_or_admin),
):
    """上传视频文件。"""
    course = (
        db.query(Course)
        .filter(Course.uuid == course_uuid, Course.status != "deleted")
        .first()
    )
    if course is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Course not found")

    if current_user.role != "admin" and course.teacher_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only the course teacher can upload to this course",
        )

    ext = os.path.splitext(file.filename or "")[1].lower()
    if ext not in ALLOWED_VIDEO_EXTENSIONS:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Unsupported video format: {ext}. Allowed: {', '.join(ALLOWED_VIDEO_EXTENSIONS)}",
        )
    if file.content_type and file.content_type not in ALLOWED_VIDEO_MIMES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Unsupported MIME type: {file.content_type}",
        )

    _ensure_dir(UPLOAD_VIDEO_DIR)
    file_uuid = str(uuid.uuid4())
    save_name = f"{file_uuid}{ext}"
    save_path = os.path.join(UPLOAD_VIDEO_DIR, save_name)

    total_size = 0
    with open(save_path, "wb") as f:
        while chunk := await file.read(1024 * 1024):  # 1 MB chunks
            total_size += len(chunk)
            if total_size > MAX_VIDEO_SIZE:
                f.close()
                os.remove(save_path)
                raise HTTPException(
                    status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
                    detail=f"Video exceeds maximum size of {MAX_VIDEO_SIZE // (1024*1024)} MB",
                )
            f.write(chunk)

    return FileUploadOut(
        file_path=save_path,
        file_size=total_size,
        original_name=file.filename or "unknown",
    )


@router.post("/upload/cover", response_model=FileUploadOut, status_code=status.HTTP_201_CREATED)
async def upload_cover(
    file: UploadFile,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_teacher_or_admin),
):
    """上传视频封面图片。"""
    ext = os.path.splitext(file.filename or "")[1].lower()
    if ext not in ALLOWED_COVER_EXTENSIONS:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Unsupported image format: {ext}. Allowed: {', '.join(ALLOWED_COVER_EXTENSIONS)}",
        )
    if file.content_type and file.content_type not in ALLOWED_COVER_MIMES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Unsupported MIME type: {file.content_type}",
        )

    _ensure_dir(UPLOAD_COVER_DIR)
    file_uuid = str(uuid.uuid4())
    save_name = f"{file_uuid}{ext}"
    save_path = os.path.join(UPLOAD_COVER_DIR, save_name)

    total_size = 0
    with open(save_path, "wb") as f:
        while chunk := await file.read(1024 * 1024):
            total_size += len(chunk)
            if total_size > MAX_COVER_SIZE:
                f.close()
                os.remove(save_path)
                raise HTTPException(
                    status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
                    detail=f"Cover image exceeds maximum size of {MAX_COVER_SIZE // (1024*1024)} MB",
                )
            f.write(chunk)

    return FileUploadOut(
        file_path=save_path,
        file_size=total_size,
        original_name=file.filename or "unknown",
    )


@router.get("/cover/{video_uuid}")
def get_cover(
    video_uuid: str,
    db: Session = Depends(get_db),
):
    """获取视频封面图片（公开访问，无需鉴权）。"""
    from models import Video

    from fastapi.responses import FileResponse

    video = (
        db.query(Video)
        .filter(Video.uuid == video_uuid, Video.status != "deleted")
        .first()
    )
    if video is None or not video.cover_path:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Cover not found")

    if not os.path.isfile(video.cover_path):
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Cover file not found on disk")

    ext = os.path.splitext(video.cover_path)[1].lower()
    mime_map = {".jpg": "image/jpeg", ".jpeg": "image/jpeg", ".png": "image/png", ".webp": "image/webp"}
    media_type = mime_map.get(ext, "application/octet-stream")

    return FileResponse(video.cover_path, media_type=media_type)
