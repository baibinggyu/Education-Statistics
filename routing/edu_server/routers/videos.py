from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from ..database import get_db
from ..deps import get_current_user, require_teacher_or_admin
from ..models import User, Course, CourseMember, Video
from ..schemas import VideoCreate, VideoOut

router = APIRouter(prefix="/api/videos", tags=["videos"])


def check_course_access(db: Session, course_id: int, user: User) -> bool:
    if user.role == "admin":
        return True
    return (
        db.query(CourseMember)
        .filter(
            CourseMember.course_id == course_id,
            CourseMember.user_id == user.id,
        )
        .first()
        is not None
    )


@router.post("/", response_model=VideoOut, status_code=status.HTTP_201_CREATED)
def create_video(
    body: VideoCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_teacher_or_admin),
):
    course = db.query(Course).filter(Course.uuid == body.course_uuid).first()
    if not course:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="课程不存在")
    if course.status != "normal":
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="课程状态异常")

    if current_user.role != "admin" and course.teacher_id != current_user.id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="只有课程教师或管理员可以上传视频")

    video = Video(
        course_id=course.id,
        uploader_id=current_user.id,
        title=body.title,
        description=body.description,
        file_path=body.file_path,
        cover_path=body.cover_path,
        duration=body.duration,
        file_size=body.file_size,
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
    course = db.query(Course).filter(Course.uuid == course_uuid).first()
    if not course:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="课程不存在")
    if not check_course_access(db, course.id, current_user):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="无权访问该课程的视频")

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
    video = db.query(Video).filter(Video.uuid == video_uuid).first()
    if not video:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="视频不存在")
    if video.status != "normal" and current_user.role != "admin":
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="视频不存在")
    if not check_course_access(db, video.course_id, current_user):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="无权访问该视频")
    return video
