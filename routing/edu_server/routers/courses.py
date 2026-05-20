from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from ..database import get_db
from ..deps import get_current_user, require_teacher_or_admin
from ..models import User, Course, CourseMember
from ..schemas import CourseCreate, CourseOut

router = APIRouter(prefix="/api/courses", tags=["courses"])


@router.post("/", response_model=CourseOut, status_code=status.HTTP_201_CREATED)
def create_course(
    body: CourseCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_teacher_or_admin),
):
    course = Course(
        name=body.name,
        description=body.description,
        teacher_id=current_user.id,
    )
    db.add(course)
    db.flush()

    member = CourseMember(
        course_id=course.id,
        user_id=current_user.id,
        member_role="teacher",
    )
    db.add(member)
    db.commit()
    db.refresh(course)
    return course


@router.get("/", response_model=list[CourseOut])
def list_courses(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    if current_user.role == "admin":
        courses = db.query(Course).filter(Course.status == "normal").all()
    else:
        courses = (
            db.query(Course)
            .join(CourseMember, CourseMember.course_id == Course.id)
            .filter(CourseMember.user_id == current_user.id)
            .filter(Course.status == "normal")
            .all()
        )
    return courses


@router.get("/{course_uuid}", response_model=CourseOut)
def get_course(
    course_uuid: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    course = db.query(Course).filter(Course.uuid == course_uuid).first()
    if not course:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="课程不存在")
    if course.status != "normal" and current_user.role != "admin":
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="课程不存在")
    if current_user.role != "admin":
        is_member = (
            db.query(CourseMember)
            .filter(
                CourseMember.course_id == course.id,
                CourseMember.user_id == current_user.id,
            )
            .first()
        )
        if not is_member:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="无权访问该课程")
    return course
