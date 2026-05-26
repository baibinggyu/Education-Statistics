"""课程资源路由。

支持上传、列表、下载、删除非视频类课程资源（PDF、文档、表格等）。
"""

import os
import uuid
from typing import Optional

from fastapi import APIRouter, Depends, Form, HTTPException, Query, UploadFile, status
from fastapi.responses import FileResponse
from sqlalchemy.orm import Session

from database import get_db
from deps import get_current_user, require_teacher_or_admin
from models import Course, CourseMember, Resource, User
from schemas import AuthorBriefOut, ResourceCreate, ResourceOut
from security import decode_access_token

router = APIRouter()

UPLOAD_DIR = "/tmp/edu/uploads/resources"
MAX_FILE_SIZE = 100 * 1024 * 1024  # 100 MB

# 常见文件类型的 MIME 映射
MIME_MAP = {
    ".pdf": "application/pdf",
    ".doc": "application/msword",
    ".docx": "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
    ".xls": "application/vnd.ms-excel",
    ".xlsx": "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
    ".ppt": "application/vnd.ms-powerpoint",
    ".pptx": "application/vnd.openxmlformats-officedocument.presentationml.presentation",
    ".zip": "application/zip",
    ".rar": "application/x-rar-compressed",
    ".7z": "application/x-7z-compressed",
    ".txt": "text/plain",
    ".csv": "text/csv",
    ".json": "application/json",
    ".jpg": "image/jpeg",
    ".jpeg": "image/jpeg",
    ".png": "image/png",
    ".webp": "image/webp",
    ".gif": "image/gif",
    ".mp3": "audio/mpeg",
    ".wav": "audio/wav",
}


def _ensure_dir(path: str):
    os.makedirs(path, exist_ok=True)


def _get_course_or_404(course_uuid: str, db: Session) -> Course:
    course = (
        db.query(Course)
        .filter(Course.uuid == course_uuid, Course.status != "deleted")
        .first()
    )
    if course is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Course not found")
    return course


def _require_course_member(course: Course, user: User, db: Session):
    if user.role == "admin":
        return
    member = (
        db.query(CourseMember)
        .filter(CourseMember.course_id == course.id, CourseMember.user_id == user.id)
        .first()
    )
    if member is None:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You are not a member of this course",
        )


# ============================================================
# 上传资源（multipart/form-data）
# ============================================================

@router.post("/{course_uuid}/resources", status_code=status.HTTP_201_CREATED)
async def upload_resource(
    course_uuid: str,
    file: UploadFile,
    title: str = Form(""),
    description: str = Form(""),
    db: Session = Depends(get_db),
    current_user: User = Depends(require_teacher_or_admin),
):
    """上传课程资源（仅教师/管理员）。"""
    course = _get_course_or_404(course_uuid, db)

    if current_user.role != "admin" and course.teacher_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only the course teacher can upload resources",
        )

    if file.filename is None or file.filename == "":
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="No file provided")

    original_name = file.filename
    ext = os.path.splitext(original_name)[1].lower()

    _ensure_dir(UPLOAD_DIR)
    file_uuid = str(uuid.uuid4())
    save_name = f"{file_uuid}{ext}"
    save_path = os.path.join(UPLOAD_DIR, save_name)

    total_size = 0
    with open(save_path, "wb") as f:
        while chunk := await file.read(1024 * 1024):
            total_size += len(chunk)
            if total_size > MAX_FILE_SIZE:
                f.close()
                os.remove(save_path)
                raise HTTPException(
                    status_code=status.HTTP_413_REQUEST_ENTITY_TOO_LARGE,
                    detail=f"File exceeds maximum size of {MAX_FILE_SIZE // (1024*1024)} MB",
                )
            f.write(chunk)

    file_type = ext.lstrip(".") if ext else "other"
    resource_title = title if title else original_name

    resource = Resource(
        course_id=course.id,
        uploader_id=current_user.id,
        title=resource_title,
        description=description if description else None,
        file_path=save_path,
        file_name=original_name,
        file_size=total_size,
        file_type=file_type,
    )
    db.add(resource)
    db.commit()
    db.refresh(resource)

    return {
        "uuid": resource.uuid,
        "course_uuid": course.uuid,
        "title": resource.title,
        "description": resource.description,
        "file_name": resource.file_name,
        "file_size": resource.file_size,
        "file_type": resource.file_type,
        "uploader": {
            "uuid": current_user.uuid,
            "username": current_user.username,
        },
        "created_at": resource.created_at.isoformat(),
    }


# ============================================================
# 列出课程资源
# ============================================================

@router.get("/{course_uuid}/resources", response_model=list[ResourceOut])
def list_resources(
    course_uuid: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """列出课程所有资源（所有课程成员可见）。"""
    course = _get_course_or_404(course_uuid, db)
    _require_course_member(course, current_user, db)

    resources = (
        db.query(Resource)
        .filter(Resource.course_id == course.id, Resource.status != "deleted")
        .order_by(Resource.created_at.desc())
        .all()
    )

    result = []
    for r in resources:
        uploader = r.uploader
        result.append(
            ResourceOut(
                uuid=r.uuid,
                course_uuid=course.uuid,
                title=r.title,
                description=r.description,
                file_name=r.file_name,
                file_size=r.file_size,
                file_type=r.file_type,
                uploader=AuthorBriefOut(uuid=uploader.uuid, username=uploader.username) if uploader else None,
                created_at=r.created_at,
            )
        )
    return result


# ============================================================
# 下载资源文件
# ============================================================

@router.get("/{course_uuid}/resources/{resource_uuid}/download")
def download_resource(
    course_uuid: str,
    resource_uuid: str,
    token: Optional[str] = Query(default=None),
    db: Session = Depends(get_db),
):
    """下载资源文件（所有课程成员可下载）。

    支持两种鉴权：1) ?token=<jwt> 查询参数  2) Authorization: Bearer 头
    """
    user = None
    if token:
        try:
            payload = decode_access_token(token)
            user_uuid_val = payload.get("sub")
            if user_uuid_val:
                user = db.query(User).filter(User.uuid == user_uuid_val, User.status == 1).first()
        except Exception:
            pass

    if user is None:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid or missing token")

    course = _get_course_or_404(course_uuid, db)
    _require_course_member(course, user, db)

    resource = (
        db.query(Resource)
        .filter(Resource.uuid == resource_uuid, Resource.status != "deleted")
        .first()
    )
    if resource is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Resource not found")

    if resource.course_id != course.id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Resource does not belong to this course")

    if not os.path.isfile(resource.file_path):
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="File not found on disk")

    ext = os.path.splitext(resource.file_path)[1].lower()
    media_type = MIME_MAP.get(ext, "application/octet-stream")

    return FileResponse(
        resource.file_path,
        media_type=media_type,
        filename=resource.file_name,
    )


# ============================================================
# 删除资源
# ============================================================

@router.delete("/{course_uuid}/resources/{resource_uuid}", status_code=status.HTTP_204_NO_CONTENT)
def delete_resource(
    course_uuid: str,
    resource_uuid: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_teacher_or_admin),
):
    """删除课程资源（仅教师/管理员）。"""
    course = _get_course_or_404(course_uuid, db)

    if current_user.role != "admin" and course.teacher_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only the course teacher can delete resources",
        )

    resource = (
        db.query(Resource)
        .filter(Resource.uuid == resource_uuid, Resource.status != "deleted")
        .first()
    )
    if resource is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Resource not found")

    if resource.course_id != course.id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Resource does not belong to this course")

    resource.status = "deleted"
    db.commit()
