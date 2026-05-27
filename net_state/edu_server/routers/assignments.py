import os
import uuid as _uuid
from datetime import datetime

from typing import Optional
from fastapi import APIRouter, Depends, File, Form, HTTPException, Query, UploadFile, status
from sqlalchemy.orm import Session

from database import get_db
from deps import get_current_user, require_teacher_or_admin
from models import Assignment, Course, CourseMember, Submission, User
from schemas import AssignmentCreate, AssignmentOut, AssignmentUpdate, AuthorBriefOut, SubmissionGrade, SubmissionOut
from security import decode_access_token

router = APIRouter()

UPLOAD_DIR = "/tmp/edu/uploads/assignments"
os.makedirs(UPLOAD_DIR, exist_ok=True)


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


def _require_course_student(course: Course, user: User, db: Session):
    """Only students (not teachers) can submit homework."""
    if user.role == "admin":
        return  # admin can do anything
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
    if member.member_role != "student":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only students can submit homework",
        )


def _build_assignment_out(a: Assignment, course: Course) -> AssignmentOut:
    author = a.author
    submission_count = len(a.submissions) if a.submissions else 0
    return AssignmentOut(
        uuid=a.uuid,
        course_uuid=course.uuid,
        title=a.title,
        description=a.description,
        due_date=a.due_date,
        total_points=a.total_points,
        has_attachment=bool(a.attachment_path),
        attachment_name=a.attachment_name,
        status=a.status,
        author=AuthorBriefOut(uuid=author.uuid, username=author.username) if author else None,
        submission_count=submission_count,
        created_at=a.created_at,
        updated_at=a.updated_at,
    )


def _build_submission_out(s: Submission, assignment_uuid: str) -> SubmissionOut:
    student = s.student
    student_name = student.username
    student_no = None
    if student.student:
        student_name = student.student.real_name or student.username
        student_no = student.student.student_no
    return SubmissionOut(
        uuid=s.uuid,
        assignment_uuid=assignment_uuid,
        student_uuid=student.uuid,
        student_name=student_name,
        student_no=student_no,
        content=s.content,
        file_name=s.file_name,
        submitted_at=s.submitted_at,
        score=s.score,
        feedback=s.feedback,
        status=s.status,
        created_at=s.created_at,
        updated_at=s.updated_at,
    )


# ============================================================
# Assignment CRUD
# ============================================================

@router.post("/{course_uuid}/assignments", response_model=AssignmentOut, status_code=status.HTTP_201_CREATED)
def create_assignment(
    course_uuid: str,
    data: AssignmentCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_teacher_or_admin),
):
    course = _get_course_or_404(course_uuid, db)
    _require_course_teacher_or_admin(course, current_user)

    assignment = Assignment(
        course_id=course.id,
        author_id=current_user.id,
        title=data.title,
        description=data.description,
        due_date=data.due_date,
        total_points=data.total_points,
    )
    db.add(assignment)
    db.commit()
    db.refresh(assignment)

    return _build_assignment_out(assignment, course)


@router.get("/{course_uuid}/assignments", response_model=list[AssignmentOut])
def list_assignments(
    course_uuid: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    course = _get_course_or_404(course_uuid, db)
    _require_course_member(course, current_user, db)

    assignments = (
        db.query(Assignment)
        .filter(Assignment.course_id == course.id)
        .order_by(Assignment.created_at.desc())
        .all()
    )

    return [_build_assignment_out(a, course) for a in assignments]


@router.get("/{course_uuid}/assignments/{assignment_uuid}", response_model=AssignmentOut)
def get_assignment(
    course_uuid: str,
    assignment_uuid: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    course = _get_course_or_404(course_uuid, db)
    _require_course_member(course, current_user, db)

    a = (
        db.query(Assignment)
        .filter(Assignment.uuid == assignment_uuid)
        .first()
    )
    if a is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Assignment not found")

    return _build_assignment_out(a, course)


@router.patch("/{course_uuid}/assignments/{assignment_uuid}", response_model=AssignmentOut)
def update_assignment(
    course_uuid: str,
    assignment_uuid: str,
    data: AssignmentUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_teacher_or_admin),
):
    course = _get_course_or_404(course_uuid, db)
    _require_course_teacher_or_admin(course, current_user)

    a = (
        db.query(Assignment)
        .filter(Assignment.uuid == assignment_uuid)
        .first()
    )
    if a is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Assignment not found")

    if data.title is not None:
        a.title = data.title
    if data.description is not None:
        a.description = data.description
    if data.due_date is not None:
        a.due_date = data.due_date
    if data.total_points is not None:
        a.total_points = data.total_points
    if data.status is not None:
        a.status = data.status

    db.commit()
    db.refresh(a)

    return _build_assignment_out(a, course)


@router.delete("/{course_uuid}/assignments/{assignment_uuid}", status_code=status.HTTP_204_NO_CONTENT)
def delete_assignment(
    course_uuid: str,
    assignment_uuid: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_teacher_or_admin),
):
    course = _get_course_or_404(course_uuid, db)
    _require_course_teacher_or_admin(course, current_user)

    a = (
        db.query(Assignment)
        .filter(Assignment.uuid == assignment_uuid)
        .first()
    )
    if a is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Assignment not found")

    # Delete submissions first to avoid FK constraint
    db.query(Submission).filter(Submission.assignment_id == a.id).delete()
    db.delete(a)
    db.commit()


# ============================================================
# Submission
# ============================================================

@router.post("/{course_uuid}/assignments/{assignment_uuid}/submissions", response_model=SubmissionOut, status_code=status.HTTP_201_CREATED)
async def submit_homework(
    course_uuid: str,
    assignment_uuid: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
    content: str = Form(default=""),
    file: UploadFile | None = None,
):
    course = _get_course_or_404(course_uuid, db)
    _require_course_student(course, current_user, db)

    a = (
        db.query(Assignment)
        .filter(Assignment.uuid == assignment_uuid)
        .first()
    )
    if a is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Assignment not found")
    if a.status == "closed":
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Assignment is closed")

    if not content and (not file or not file.filename):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Either content or file must be provided",
        )

    # Check if already submitted (upsert)
    existing = (
        db.query(Submission)
        .filter(Submission.assignment_id == a.id, Submission.student_id == current_user.id)
        .first()
    )

    # Determine late status
    now = datetime.now()
    sub_status = "submitted"
    if a.due_date and now > a.due_date:
        sub_status = "late"

    # Save uploaded file
    file_path = None
    file_name = None
    if file and file.filename:
        file_name = file.filename
        safe_name = f"{_uuid.uuid4().hex}_{file.filename}"
        file_path = os.path.join(UPLOAD_DIR, safe_name)
        content_bytes = await file.read()
        with open(file_path, "wb") as f:
            f.write(content_bytes)

    if existing:
        existing.content = content or existing.content
        if file_path:
            existing.file_path = file_path
            existing.file_name = file_name
        existing.submitted_at = now
        existing.status = sub_status
        existing.score = None  # reset grade on resubmit
        existing.feedback = None
        db.commit()
        db.refresh(existing)
        return _build_submission_out(existing, a.uuid)
    else:
        submission = Submission(
            assignment_id=a.id,
            student_id=current_user.id,
            content=content or None,
            file_path=file_path,
            file_name=file_name,
            submitted_at=now,
            status=sub_status,
        )
        db.add(submission)
        db.commit()
        db.refresh(submission)
        return _build_submission_out(submission, a.uuid)


@router.get("/{course_uuid}/assignments/{assignment_uuid}/submissions", response_model=list[SubmissionOut])
def list_submissions(
    course_uuid: str,
    assignment_uuid: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_teacher_or_admin),
):
    course = _get_course_or_404(course_uuid, db)
    _require_course_teacher_or_admin(course, current_user)

    a = (
        db.query(Assignment)
        .filter(Assignment.uuid == assignment_uuid)
        .first()
    )
    if a is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Assignment not found")

    submissions = (
        db.query(Submission)
        .filter(Submission.assignment_id == a.id)
        .order_by(Submission.submitted_at.desc())
        .all()
    )

    return [_build_submission_out(s, a.uuid) for s in submissions]


@router.get("/{course_uuid}/assignments/{assignment_uuid}/submissions/my", response_model=SubmissionOut | dict)
def get_my_submission(
    course_uuid: str,
    assignment_uuid: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    course = _get_course_or_404(course_uuid, db)
    _require_course_member(course, current_user, db)

    a = (
        db.query(Assignment)
        .filter(Assignment.uuid == assignment_uuid)
        .first()
    )
    if a is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Assignment not found")

    submission = (
        db.query(Submission)
        .filter(Submission.assignment_id == a.id, Submission.student_id == current_user.id)
        .first()
    )

    if submission is None:
        return {"submitted": False}

    return _build_submission_out(submission, a.uuid)


@router.patch("/{course_uuid}/assignments/{assignment_uuid}/submissions/{submission_uuid}", response_model=SubmissionOut)
def grade_submission(
    course_uuid: str,
    assignment_uuid: str,
    submission_uuid: str,
    data: SubmissionGrade,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_teacher_or_admin),
):
    course = _get_course_or_404(course_uuid, db)
    _require_course_teacher_or_admin(course, current_user)

    a = (
        db.query(Assignment)
        .filter(Assignment.uuid == assignment_uuid)
        .first()
    )
    if a is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Assignment not found")

    s = (
        db.query(Submission)
        .filter(Submission.uuid == submission_uuid)
        .first()
    )
    if s is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Submission not found")

    if data.score is not None:
        s.score = data.score
    if data.feedback is not None:
        s.feedback = data.feedback
    s.status = "graded"

    db.commit()
    db.refresh(s)

    return _build_submission_out(s, a.uuid)


@router.get("/{course_uuid}/assignments/{assignment_uuid}/submissions/{submission_uuid}/file")
def download_submission_file(
    course_uuid: str,
    assignment_uuid: str,
    submission_uuid: str,
    token: Optional[str] = Query(default=None),
    db: Session = Depends(get_db),
):
    """Download a student's submitted file. Supports ?token=<jwt> for browser access."""
    from fastapi.responses import FileResponse
    from jose import JWTError

    user = None
    if token:
        try:
            payload = decode_access_token(token)
            uid = payload.get("sub")
            if uid:
                user = db.query(User).filter(User.uuid == uid, User.status == 1).first()
        except JWTError:
            pass

    if user is None:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid or missing token")

    course = _get_course_or_404(course_uuid, db)

    # Only teachers/admin can download submissions
    if user.role != "admin" and course.teacher_id != user.id:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Only teachers can download submissions")

    a = (
        db.query(Assignment)
        .filter(Assignment.uuid == assignment_uuid)
        .first()
    )
    if a is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Assignment not found")

    s = (
        db.query(Submission)
        .filter(Submission.uuid == submission_uuid)
        .first()
    )
    if s is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Submission not found")
    if not s.file_path or not os.path.isfile(s.file_path):
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="No file attached")

    return FileResponse(s.file_path, filename=s.file_name or "submission")
