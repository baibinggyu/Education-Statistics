from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from database import get_db
from deps import get_current_user, require_teacher_or_admin
from models import Announcement, Course, CourseMember, User
from schemas import AnnouncementCreate, AnnouncementOut, AnnouncementUpdate, AuthorBriefOut

router = APIRouter()


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
# 公告 CRUD
# ============================================================

@router.post("/{course_uuid}/announcements", response_model=AnnouncementOut, status_code=status.HTTP_201_CREATED)
def create_announcement(
    course_uuid: str,
    data: AnnouncementCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_teacher_or_admin),
):
    course = _get_course_or_404(course_uuid, db)
    _require_course_teacher_or_admin(course, current_user)

    announcement = Announcement(
        course_id=course.id,
        author_id=current_user.id,
        title=data.title,
        content=data.content,
        ann_type=data.ann_type,
        pinned=data.pinned,
        notify=data.notify,
    )
    db.add(announcement)
    db.commit()
    db.refresh(announcement)

    return AnnouncementOut(
        uuid=announcement.uuid,
        course_uuid=course.uuid,
        title=announcement.title,
        content=announcement.content,
        ann_type=announcement.ann_type,
        pinned=announcement.pinned,
        notify=announcement.notify,
        author=AuthorBriefOut(uuid=current_user.uuid, username=current_user.username),
        created_at=announcement.created_at,
        updated_at=announcement.updated_at,
    )


@router.get("/{course_uuid}/announcements", response_model=list[AnnouncementOut])
def list_announcements(
    course_uuid: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    course = _get_course_or_404(course_uuid, db)
    _require_course_member(course, current_user, db)

    announcements = (
        db.query(Announcement)
        .filter(Announcement.course_id == course.id, Announcement.status != "deleted")
        .order_by(Announcement.pinned.desc(), Announcement.created_at.desc())
        .all()
    )

    result = []
    for a in announcements:
        author = a.author
        result.append(
            AnnouncementOut(
                uuid=a.uuid,
                course_uuid=course.uuid,
                title=a.title,
                content=a.content,
                ann_type=a.ann_type,
                pinned=a.pinned,
                notify=a.notify,
                author=AuthorBriefOut(uuid=author.uuid, username=author.username) if author else None,
                created_at=a.created_at,
                updated_at=a.updated_at,
            )
        )
    return result


@router.get("/{course_uuid}/announcements/{announcement_uuid}", response_model=AnnouncementOut)
def get_announcement(
    course_uuid: str,
    announcement_uuid: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    course = _get_course_or_404(course_uuid, db)
    _require_course_member(course, current_user, db)

    a = (
        db.query(Announcement)
        .filter(Announcement.uuid == announcement_uuid, Announcement.status != "deleted")
        .first()
    )
    if a is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Announcement not found")

    author = a.author
    return AnnouncementOut(
        uuid=a.uuid,
        course_uuid=course.uuid,
        title=a.title,
        content=a.content,
        ann_type=a.ann_type,
        pinned=a.pinned,
        notify=a.notify,
        author=AuthorBriefOut(uuid=author.uuid, username=author.username) if author else None,
        created_at=a.created_at,
        updated_at=a.updated_at,
    )


@router.patch("/{course_uuid}/announcements/{announcement_uuid}", response_model=AnnouncementOut)
def update_announcement(
    course_uuid: str,
    announcement_uuid: str,
    data: AnnouncementUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_teacher_or_admin),
):
    course = _get_course_or_404(course_uuid, db)
    _require_course_teacher_or_admin(course, current_user)

    a = (
        db.query(Announcement)
        .filter(Announcement.uuid == announcement_uuid, Announcement.status != "deleted")
        .first()
    )
    if a is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Announcement not found")

    if data.title is not None:
        a.title = data.title
    if data.content is not None:
        a.content = data.content
    if data.ann_type is not None:
        a.ann_type = data.ann_type
    if data.pinned is not None:
        a.pinned = data.pinned
    if data.notify is not None:
        a.notify = data.notify

    db.commit()
    db.refresh(a)

    author = a.author
    return AnnouncementOut(
        uuid=a.uuid,
        course_uuid=course.uuid,
        title=a.title,
        content=a.content,
        ann_type=a.ann_type,
        pinned=a.pinned,
        notify=a.notify,
        author=AuthorBriefOut(uuid=author.uuid, username=author.username) if author else None,
        created_at=a.created_at,
        updated_at=a.updated_at,
    )


@router.delete("/{course_uuid}/announcements/{announcement_uuid}", status_code=status.HTTP_204_NO_CONTENT)
def delete_announcement(
    course_uuid: str,
    announcement_uuid: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_teacher_or_admin),
):
    course = _get_course_or_404(course_uuid, db)
    _require_course_teacher_or_admin(course, current_user)

    a = (
        db.query(Announcement)
        .filter(Announcement.uuid == announcement_uuid, Announcement.status != "deleted")
        .first()
    )
    if a is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Announcement not found")

    a.status = "deleted"
    db.commit()
