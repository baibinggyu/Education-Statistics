from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from database import get_db
from deps import get_current_user, require_teacher_or_admin
from models import Course, CourseMember, Unit, User
from schemas import UnitCreate, UnitOut, UnitReorderItem, UnitUpdate

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
# 单元 CRUD (挂载在 courses router 下, 路径: /{course_uuid}/units)
# ============================================================

@router.post("/units", response_model=UnitOut, status_code=status.HTTP_201_CREATED, tags=["units"])
def create_unit(
    course_uuid: str,
    data: UnitCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_teacher_or_admin),
):
    course = _get_course_or_404(course_uuid, db)
    _require_course_teacher_or_admin(course, current_user)

    exists = (
        db.query(Unit)
        .filter(Unit.course_id == course.id, Unit.name == data.name)
        .first()
    )
    if exists:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Unit name already exists in this course",
        )

    unit = Unit(
        course_id=course.id,
        name=data.name,
        weight=data.weight,
        full_score=data.full_score,
        unit_order=data.unit_order,
    )
    db.add(unit)
    db.commit()
    db.refresh(unit)
    return unit


@router.get("/units", response_model=list[UnitOut], tags=["units"])
def list_units(
    course_uuid: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    course = _get_course_or_404(course_uuid, db)
    _require_course_member(course, current_user, db)

    return (
        db.query(Unit)
        .filter(Unit.course_id == course.id)
        .order_by(Unit.unit_order)
        .all()
    )


@router.patch("/units/{unit_id}", response_model=UnitOut, tags=["units"])
def update_unit(
    course_uuid: str,
    unit_id: int,
    data: UnitUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_teacher_or_admin),
):
    course = _get_course_or_404(course_uuid, db)
    _require_course_teacher_or_admin(course, current_user)

    unit = (
        db.query(Unit)
        .filter(Unit.id == unit_id, Unit.course_id == course.id)
        .first()
    )
    if unit is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Unit not found")

    if data.name is not None:
        dup = (
            db.query(Unit)
            .filter(Unit.course_id == course.id, Unit.name == data.name, Unit.id != unit_id)
            .first()
        )
        if dup:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="Unit name already exists in this course",
            )
        unit.name = data.name
    if data.weight is not None:
        unit.weight = data.weight
    if data.full_score is not None:
        unit.full_score = data.full_score
    if data.unit_order is not None:
        unit.unit_order = data.unit_order

    db.commit()
    db.refresh(unit)
    return unit


@router.delete("/units/{unit_id}", status_code=status.HTTP_204_NO_CONTENT, tags=["units"])
def delete_unit(
    course_uuid: str,
    unit_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_teacher_or_admin),
):
    course = _get_course_or_404(course_uuid, db)
    _require_course_teacher_or_admin(course, current_user)

    unit = (
        db.query(Unit)
        .filter(Unit.id == unit_id, Unit.course_id == course.id)
        .first()
    )
    if unit is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Unit not found")

    # 先删除关联的成绩
    from models import Score
    db.query(Score).filter(Score.unit_id == unit.id).delete()
    db.delete(unit)
    db.commit()


@router.post("/units/reorder", status_code=status.HTTP_204_NO_CONTENT, tags=["units"])
def reorder_units(
    course_uuid: str,
    items: list[UnitReorderItem],
    db: Session = Depends(get_db),
    current_user: User = Depends(require_teacher_or_admin),
):
    course = _get_course_or_404(course_uuid, db)
    _require_course_teacher_or_admin(course, current_user)

    for item in items:
        unit = (
            db.query(Unit)
            .filter(Unit.id == item.unit_id, Unit.course_id == course.id)
            .first()
        )
        if unit:
            unit.unit_order = item.unit_order

    db.commit()
