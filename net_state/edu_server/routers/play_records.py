"""播放记录路由。

视频播放进度上报与查询。INSERT ... ON DUPLICATE KEY UPDATE 模式。
"""

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from database import get_db
from deps import get_current_user
from models import CourseMember, PlayRecord, User, Video
from schemas import PlayRecordCourseOut, PlayRecordOut, PlayRecordUpdate

router = APIRouter()


def _check_course_access(course_id: int, user: User, db: Session) -> bool:
    if user.role == "admin":
        return True
    member = (
        db.query(CourseMember)
        .filter(CourseMember.course_id == course_id, CourseMember.user_id == user.id)
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
        .filter(Video.uuid == data.video_uuid, Video.status == "normal")
        .first()
    )
    if video is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Video not found")

    if not _check_course_access(video.course_id, current_user, db):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You are not a member of this video's course",
        )

    record = (
        db.query(PlayRecord)
        .filter(PlayRecord.user_id == current_user.id, PlayRecord.video_id == video.id)
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

    return PlayRecordOut(
        video_uuid=video.uuid,
        progress=record.progress,
        completed=record.completed,
        last_played_at=record.last_played_at,
    )


@router.get("/{video_uuid}", response_model=PlayRecordOut)
def get_play_record(
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

    record = (
        db.query(PlayRecord)
        .filter(PlayRecord.user_id == current_user.id, PlayRecord.video_id == video.id)
        .first()
    )

    if record is None:
        return PlayRecordOut(
            video_uuid=video.uuid,
            progress=0,
            completed=False,
        )

    return PlayRecordOut(
        video_uuid=video.uuid,
        progress=record.progress,
        completed=record.completed,
        last_played_at=record.last_played_at,
    )


@router.get("/course/{course_uuid}/my", response_model=list[PlayRecordCourseOut])
def get_my_course_records(
    course_uuid: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """获取当前用户在某课程下所有视频的播放进度。"""
    videos = (
        db.query(Video)
        .join(Video.course)
        .filter(Video.course.has(uuid=course_uuid))
        .filter(Video.status == "normal")
        .all()
    )
    if not videos:
        return []

    video_ids = [v.id for v in videos]
    records = {
        r.video_id: r
        for r in db.query(PlayRecord)
        .filter(
            PlayRecord.user_id == current_user.id,
            PlayRecord.video_id.in_(video_ids),
        )
        .all()
    }

    return [
        PlayRecordCourseOut(
            video_uuid=v.uuid,
            video_title=v.title,
            progress=records[v.id].progress if v.id in records else 0,
            duration=v.duration,
            completed=records[v.id].completed if v.id in records else False,
            last_played_at=records[v.id].last_played_at if v.id in records else None,
        )
        for v in videos
    ]
