from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from database import get_db
from deps import get_current_user
from models import Course, CourseMember, Message, User
from schemas import AuthorBriefOut, MessageCreate, MessageOut

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
# 消息 CRUD
# ============================================================

@router.post("/{course_uuid}/messages", response_model=MessageOut, status_code=status.HTTP_201_CREATED)
def send_message(
    course_uuid: str,
    data: MessageCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    course = _get_course_or_404(course_uuid, db)
    _require_course_member(course, current_user, db)

    # Student restriction: can only send to course teacher, not to other students
    if current_user.role == "student":
        if data.recipient_username:
            teacher = course.teacher
            if data.recipient_username != teacher.username:
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail="Students can only send messages to the course teacher",
                )
        else:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Students cannot send broadcast messages",
            )

    recipient_id = None
    if data.recipient_username:
        recipient = db.query(User).filter(User.username == data.recipient_username).first()
        if recipient is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Recipient not found")
        # Verify recipient is in course
        is_member = (
            db.query(CourseMember)
            .filter(CourseMember.course_id == course.id, CourseMember.user_id == recipient.id)
            .first()
        )
        if is_member is None:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Recipient is not a member of this course",
            )
        recipient_id = recipient.id

    message = Message(
        course_id=course.id,
        sender_id=current_user.id,
        recipient_id=recipient_id,
        subject=data.subject,
        content=data.content,
        msg_type=data.msg_type,
    )
    db.add(message)
    db.commit()
    db.refresh(message)

    sender_out = AuthorBriefOut(uuid=current_user.uuid, username=current_user.username)
    recipient_out = None
    if recipient_id:
        rec = db.query(User).filter(User.id == recipient_id).first()
        if rec:
            recipient_out = AuthorBriefOut(uuid=rec.uuid, username=rec.username)

    return MessageOut(
        uuid=message.uuid,
        course_uuid=course.uuid,
        subject=message.subject,
        content=message.content,
        msg_type=message.msg_type,
        is_read=message.is_read,
        sender=sender_out,
        recipient=recipient_out,
        created_at=message.created_at,
    )


@router.get("/{course_uuid}/messages", response_model=list[MessageOut])
def list_messages(
    course_uuid: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    course = _get_course_or_404(course_uuid, db)
    _require_course_member(course, current_user, db)

    # Teachers/admins see all messages in course; students see messages to them or broadcast
    if current_user.role in ("teacher", "admin"):
        msgs = (
            db.query(Message)
            .filter(Message.course_id == course.id, Message.status != "deleted")
            .order_by(Message.created_at.desc())
            .all()
        )
    else:
        msgs = (
            db.query(Message)
            .filter(
                Message.course_id == course.id,
                Message.status != "deleted",
                (Message.recipient_id == current_user.id) | (Message.recipient_id.is_(None)),
            )
            .order_by(Message.created_at.desc())
            .all()
        )

    result = []
    for m in msgs:
        sender = m.sender
        recipient = m.recipient if m.recipient_id else None
        result.append(
            MessageOut(
                uuid=m.uuid,
                course_uuid=course.uuid,
                subject=m.subject,
                content=m.content,
                msg_type=m.msg_type,
                is_read=m.is_read,
                sender=AuthorBriefOut(uuid=sender.uuid, username=sender.username) if sender else None,
                recipient=AuthorBriefOut(uuid=recipient.uuid, username=recipient.username) if recipient else None,
                created_at=m.created_at,
            )
        )
    return result


@router.post("/{course_uuid}/messages/{message_uuid}/read", status_code=status.HTTP_200_OK)
def mark_message_read(
    course_uuid: str,
    message_uuid: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    course = _get_course_or_404(course_uuid, db)
    _require_course_member(course, current_user, db)

    m = (
        db.query(Message)
        .filter(Message.uuid == message_uuid, Message.status != "deleted")
        .first()
    )
    if m is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Message not found")

    m.is_read = True
    db.commit()
    return {"read": True}


@router.get("/{course_uuid}/messages/unread-count")
def get_unread_count(
    course_uuid: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    course = _get_course_or_404(course_uuid, db)
    _require_course_member(course, current_user, db)

    if current_user.role in ("teacher", "admin"):
        # Teachers see unread messages sent to them specifically (not broadcast)
        unread = (
            db.query(Message)
            .filter(
                Message.course_id == course.id,
                Message.status != "deleted",
                Message.is_read == False,
                Message.recipient_id == current_user.id,
            )
            .count()
        )
    else:
        # Students see unread messages sent to them or broadcast
        unread = (
            db.query(Message)
            .filter(
                Message.course_id == course.id,
                Message.status != "deleted",
                Message.is_read == False,
                (Message.recipient_id == current_user.id) | (Message.recipient_id.is_(None)),
            )
            .count()
        )

    total = (
        db.query(Message)
        .filter(Message.course_id == course.id, Message.status != "deleted")
        .count()
    )

    return {"unread": unread, "total": total}


@router.get("/{course_uuid}/messages/conversation/{other_uuid}", response_model=list[MessageOut])
def get_conversation(
    course_uuid: str,
    other_uuid: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """Get the direct conversation between current user and another user in this course."""
    course = _get_course_or_404(course_uuid, db)
    _require_course_member(course, current_user, db)

    other = db.query(User).filter(User.uuid == other_uuid).first()
    if other is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")

    # Get messages between current user and the other user (both directions)
    msgs = (
        db.query(Message)
        .filter(
            Message.course_id == course.id,
            Message.status != "deleted",
            (
                (Message.sender_id == current_user.id) & (Message.recipient_id == other.id)
            ) | (
                (Message.sender_id == other.id) & (Message.recipient_id == current_user.id)
            ),
        )
        .order_by(Message.created_at.asc())
        .all()
    )

    result = []
    for m in msgs:
        sender = m.sender
        recipient = m.recipient if m.recipient_id else None
        result.append(
            MessageOut(
                uuid=m.uuid,
                course_uuid=course.uuid,
                subject=m.subject,
                content=m.content,
                msg_type=m.msg_type,
                is_read=m.is_read,
                sender=AuthorBriefOut(uuid=sender.uuid, username=sender.username) if sender else None,
                recipient=AuthorBriefOut(uuid=recipient.uuid, username=recipient.username) if recipient else None,
                created_at=m.created_at,
            )
        )
    return result


@router.delete("/{course_uuid}/messages/{message_uuid}", status_code=status.HTTP_204_NO_CONTENT)
def delete_message(
    course_uuid: str,
    message_uuid: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    course = _get_course_or_404(course_uuid, db)

    m = (
        db.query(Message)
        .filter(Message.uuid == message_uuid, Message.status != "deleted")
        .first()
    )
    if m is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Message not found")

    # Only sender or course teacher can delete
    if current_user.id != m.sender_id and current_user.role != "admin" and course.teacher_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only the sender or course teacher can delete this message",
        )

    m.status = "deleted"
    db.commit()
