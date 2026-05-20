from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from ..database import get_db
from ..deps import get_current_user
from ..models import User, Course, CourseMember, Video, PlayRecord
from ..schemas import PlayRecordUpdate, PlayRecordOut

router = APIRouter(prefix="/api/play-records", tags=["play_records"])


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


@router.post("/update", response_model=PlayRecordOut)
def update_play_record(
    body: PlayRecordUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    video = db.query(Video).filter(Video.uuid == body.video_uuid).first()
    if not video:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="视频不存在")
    if not check_course_access(db, video.course_id, current_user):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="无权访问该视频")

    record = (
        db.query(PlayRecord)
        .filter(
            PlayRecord.user_id == current_user.id,
            PlayRecord.video_id == video.id,
        )
        .first()
    )
    if record:
        record.progress = body.progress
        record.completed = body.completed
    else:
        record = PlayRecord(
            user_id=current_user.id,
            video_id=video.id,
            progress=body.progress,
            completed=body.completed,
        )
        db.add(record)
    db.commit()
    db.refresh(record)
    return record


@router.get("/{video_uuid}", response_model=PlayRecordOut)
def get_play_record(
    video_uuid: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    video = db.query(Video).filter(Video.uuid == video_uuid).first()
    if not video:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="视频不存在")

    record = (
        db.query(PlayRecord)
        .filter(
            PlayRecord.user_id == current_user.id,
            PlayRecord.video_id == video.id,
        )
        .first()
    )
    if not record:
        return {"progress": 0, "completed": False}
    return record
