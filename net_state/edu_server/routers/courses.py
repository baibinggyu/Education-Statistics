from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from database import get_db
from deps import get_current_user, require_teacher_or_admin
from models import Course, CourseMember, Student, Unit, User
from schemas import (
    CourseCreate,
    CourseDetailOut,
    CourseMemberAdd,
    CourseMemberOut,
    CourseMyOut,
    CourseUpdate,
    MemberStudentOut,
    StudentImportItem,
    StudentImportResult,
    TeacherBriefOut,
)
from routers.units import router as units_router

router = APIRouter()


# ============================================================
# 辅助函数
# ============================================================

def _course_to_my_out(course: Course, user_id: int, db: Session) -> CourseMyOut:
    member = (
        db.query(CourseMember)
        .filter(CourseMember.course_id == course.id, CourseMember.user_id == user_id)
        .first()
    )
    teacher = course.teacher
    return CourseMyOut(
        uuid=course.uuid,
        name=course.name,
        description=course.description,
        teacher=TeacherBriefOut.model_validate(teacher) if teacher else None,
        status=course.status,
        member_count=db.query(CourseMember)
        .filter(CourseMember.course_id == course.id)
        .count(),
        video_count=len(course.videos) if course.videos else 0,
        my_role=member.member_role if member else "student",
        created_at=course.created_at,
    )


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
# 课程 CRUD
# ============================================================

@router.post("/", response_model=CourseMyOut, status_code=status.HTTP_201_CREATED)
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

    return _course_to_my_out(course, current_user.id, db)


@router.get("/", response_model=list[CourseMyOut])
def list_my_courses(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if current_user.role == "admin":
        courses = db.query(Course).filter(Course.status != "deleted").all()
    else:
        courses = (
            db.query(Course)
            .join(CourseMember, CourseMember.course_id == Course.id)
            .filter(CourseMember.user_id == current_user.id)
            .filter(Course.status != "deleted")
            .all()
        )
    return [_course_to_my_out(c, current_user.id, db) for c in courses]


@router.get("/{course_uuid}", response_model=CourseDetailOut)
def get_course(
    course_uuid: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    course = _get_course_or_404(course_uuid, db)
    _require_course_member(course, current_user, db)

    teacher = course.teacher
    units = (
        db.query(Unit)
        .filter(Unit.course_id == course.id)
        .order_by(Unit.unit_order)
        .all()
    )

    from schemas import UnitOut

    return CourseDetailOut(
        uuid=course.uuid,
        name=course.name,
        description=course.description,
        teacher=TeacherBriefOut.model_validate(teacher) if teacher else None,
        status=course.status,
        units=[UnitOut.model_validate(u) for u in units],
        member_count=db.query(CourseMember)
        .filter(CourseMember.course_id == course.id)
        .count(),
        created_at=course.created_at,
    )


@router.patch("/{course_uuid}", response_model=CourseMyOut)
def update_course(
    course_uuid: str,
    data: CourseUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    course = _get_course_or_404(course_uuid, db)
    _require_course_teacher_or_admin(course, current_user)

    if data.name is not None:
        course.name = data.name
    if data.description is not None:
        course.description = data.description

    db.commit()
    db.refresh(course)
    return _course_to_my_out(course, current_user.id, db)


@router.delete("/{course_uuid}", status_code=status.HTTP_204_NO_CONTENT)
def delete_course(
    course_uuid: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    course = _get_course_or_404(course_uuid, db)
    _require_course_teacher_or_admin(course, current_user)

    course.status = "deleted"
    db.commit()


# ============================================================
# 课程成员
# ============================================================

@router.get("/{course_uuid}/members", response_model=list[CourseMemberOut])
def list_members(
    course_uuid: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    course = _get_course_or_404(course_uuid, db)
    _require_course_member(course, current_user, db)

    members = (
        db.query(CourseMember)
        .filter(CourseMember.course_id == course.id)
        .all()
    )

    result = []
    for m in members:
        member_user = db.query(User).filter(User.id == m.user_id).first()
        student = None
        if m.member_role == "student":
            s = db.query(Student).filter(Student.user_id == m.user_id).first()
            if s:
                student = MemberStudentOut.model_validate(s)

        result.append(
            CourseMemberOut(
                user_uuid=member_user.uuid,
                username=member_user.username,
                member_role=m.member_role,
                joined_at=m.created_at,
                student=student,
            )
        )
    return result


@router.post("/{course_uuid}/members", response_model=CourseMemberOut, status_code=status.HTTP_201_CREATED)
def add_member(
    course_uuid: str,
    data: CourseMemberAdd,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    course = _get_course_or_404(course_uuid, db)
    _require_course_teacher_or_admin(course, current_user)

    target_user = None
    if data.username:
        target_user = db.query(User).filter(User.username == data.username).first()
    elif data.student_no:
        student = db.query(Student).filter(Student.student_no == data.student_no).first()
        if student:
            target_user = db.query(User).filter(User.id == student.user_id).first()

    if target_user is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")

    existing = (
        db.query(CourseMember)
        .filter(CourseMember.course_id == course.id, CourseMember.user_id == target_user.id)
        .first()
    )
    if existing:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="User is already a member")

    member = CourseMember(course_id=course.id, user_id=target_user.id, member_role="student")
    db.add(member)
    db.commit()
    db.refresh(member)

    student = None
    if target_user.role == "student":
        s = db.query(Student).filter(Student.user_id == target_user.id).first()
        if s:
            student = MemberStudentOut.model_validate(s)

    return CourseMemberOut(
        user_uuid=target_user.uuid,
        username=target_user.username,
        member_role=member.member_role,
        joined_at=member.created_at,
        student=student,
    )


@router.delete("/{course_uuid}/members/{user_uuid}", status_code=status.HTTP_204_NO_CONTENT)
def remove_member(
    course_uuid: str,
    user_uuid: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    course = _get_course_or_404(course_uuid, db)
    _require_course_teacher_or_admin(course, current_user)

    target = db.query(User).filter(User.uuid == user_uuid).first()
    if target is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")

    if target.id == course.teacher_id:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Cannot remove course teacher")

    member = (
        db.query(CourseMember)
        .filter(CourseMember.course_id == course.id, CourseMember.user_id == target.id)
        .first()
    )
    if member is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Member not found")

    db.delete(member)
    db.commit()


# ============================================================
# 批量导入学生
# ============================================================

@router.post("/{course_uuid}/import-students", response_model=StudentImportResult)
def import_students(
    course_uuid: str,
    data: list[StudentImportItem],
    db: Session = Depends(get_db),
    current_user: User = Depends(require_teacher_or_admin),
):
    course = _get_course_or_404(course_uuid, db)
    _require_course_teacher_or_admin(course, current_user)

    from security import hash_password

    created = 0
    skipped = 0
    errors = []

    for item in data:
        try:
            # Check if user already exists
            existing_user = db.query(User).filter(User.username == item.username).first()
            if existing_user:
                # User exists, just add to course if not already a member
                existing_member = (
                    db.query(CourseMember)
                    .filter(CourseMember.course_id == course.id, CourseMember.user_id == existing_user.id)
                    .first()
                )
                if existing_member:
                    skipped += 1
                    continue
                # Add as course member
                member = CourseMember(course_id=course.id, user_id=existing_user.id, member_role="student")
                db.add(member)
                created += 1
                continue

            # Create new user
            new_user = User(
                username=item.username,
                password_hash=hash_password(item.password),
                role="student",
            )
            db.add(new_user)
            db.flush()

            # Create student profile
            student = Student(
                user_id=new_user.id,
                student_no=item.student_no,
                real_name=item.real_name,
            )
            db.add(student)

            # Add as course member
            member = CourseMember(course_id=course.id, user_id=new_user.id, member_role="student")
            db.add(member)
            created += 1
        except Exception as e:
            errors.append(f"{item.username}: {str(e)}")

    db.commit()
    return {"total": len(data), "created": created, "skipped": skipped, "errors": errors}


# 挂载单元子路由
router.include_router(units_router, prefix="/{course_uuid}")
