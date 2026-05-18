"""成绩管理路由。

成绩录入、查询、汇总、导出。
所有端点都基于课程范围的权限校验。
"""

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from database import get_db
from deps import get_current_user, require_teacher_or_admin
from models import Course, CourseMember, Score, Student, Unit, User
from schemas import (
    MyScoreItem,
    ScoreBatchCreate,
    ScoreCreate,
    ScoreDistributionOut,
    ScoreMyOut,
    ScoreSingleOut,
    ScoreSummaryOut,
    ScoreSummaryStudent,
    UnitOut,
)

router = APIRouter()


# ============================================================
# 辅助函数
# ============================================================

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
        return True
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
    return member is not None and member.member_role == "teacher"


def _get_student_by_uuid(student_uuid: str, db: Session) -> Student:
    user = db.query(User).filter(User.uuid == student_uuid).first()
    if user is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Student user not found")
    student = db.query(Student).filter(Student.user_id == user.id).first()
    if student is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Student profile not found")
    return student


def _calc_weighted_total(scores: list[float | None], units: list[Unit]) -> float | None:
    """计算加权总分。如果有任一单元无成绩，返回 None。"""
    if any(s is None for s in scores):
        return None
    total_weight = sum(u.weight for u in units)
    if total_weight == 0:
        return None
    # 每个单元按 (score / full_score) * 100 归一化后再乘权重
    weighted_sum = 0.0
    for s, u in zip(scores, units):
        score_val = float(s)  # type: ignore
        normalized = (score_val / u.full_score) * 100 if u.full_score > 0 else score_val
        weighted_sum += normalized * u.weight
    return round(weighted_sum / total_weight, 2)


def _build_score_summary(course: Course, db: Session) -> ScoreSummaryOut:
    """构建课程成绩汇总。"""
    units = db.query(Unit).filter(Unit.course_id == course.id).order_by(Unit.unit_order).all()

    # 获取课程下所有学生
    student_members = (
        db.query(CourseMember)
        .filter(CourseMember.course_id == course.id, CourseMember.member_role == "student")
        .all()
    )

    student_records = []
    for sm in student_members:
        student = db.query(Student).filter(Student.user_id == sm.user_id).first()
        if student is None:
            continue

        student_scores = []
        for u in units:
            s = (
                db.query(Score)
                .filter(
                    Score.student_id == student.id,
                    Score.course_id == course.id,
                    Score.unit_id == u.id,
                )
                .first()
            )
            student_scores.append(s.score if s else None)

        user = db.query(User).filter(User.id == sm.user_id).first()
        weighted_total = _calc_weighted_total(student_scores, units)

        student_records.append(
            ScoreSummaryStudent(
                student_uuid=user.uuid,
                student_no=student.student_no,
                real_name=student.real_name,
                scores=student_scores,
                weighted_total=weighted_total,
            )
        )

    # 排名
    student_records.sort(
        key=lambda r: (r.weighted_total if r.weighted_total is not None else -1),
        reverse=True,
    )
    for i, rec in enumerate(student_records):
        if rec.weighted_total is not None:
            rec.rank = i + 1

    return ScoreSummaryOut(
        course_name=course.name,
        unit_names=[u.name for u in units],
        unit_weights=[u.weight for u in units],
        students=student_records,
    )


# ============================================================
# 成绩录入
# ============================================================

@router.post("/", response_model=ScoreSingleOut, status_code=status.HTTP_201_CREATED)
def create_score(
    data: ScoreCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_teacher_or_admin),
):
    course = _get_course_or_404(data.course_uuid, db)
    _require_course_teacher_or_admin(course, current_user)

    student = _get_student_by_uuid(data.student_uuid, db)

    unit = (
        db.query(Unit)
        .filter(Unit.id == data.unit_id, Unit.course_id == course.id)
        .first()
    )
    if unit is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Unit not found in this course")

    score = (
        db.query(Score)
        .filter(
            Score.student_id == student.id,
            Score.course_id == course.id,
            Score.unit_id == unit.id,
        )
        .first()
    )

    if score:
        score.score = data.score
    else:
        score = Score(
            student_id=student.id,
            course_id=course.id,
            unit_id=unit.id,
            score=data.score,
        )
        db.add(score)

    db.commit()
    db.refresh(score)

    user = db.query(User).filter(User.id == student.user_id).first()
    return ScoreSingleOut(
        student_uuid=user.uuid,
        student_no=student.student_no,
        real_name=student.real_name,
        course_uuid=course.uuid,
        unit_id=unit.id,
        unit_name=unit.name,
        score=score.score,
        updated_at=score.updated_at,
    )


@router.post("/batch", status_code=status.HTTP_204_NO_CONTENT)
def batch_create_scores(
    data: ScoreBatchCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_teacher_or_admin),
):
    course = _get_course_or_404(data.course_uuid, db)
    _require_course_teacher_or_admin(course, current_user)

    unit = (
        db.query(Unit)
        .filter(Unit.id == data.unit_id, Unit.course_id == course.id)
        .first()
    )
    if unit is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Unit not found in this course")

    for entry in data.scores:
        student = _get_student_by_uuid(entry.student_uuid, db)
        score = (
            db.query(Score)
            .filter(
                Score.student_id == student.id,
                Score.course_id == course.id,
                Score.unit_id == unit.id,
            )
            .first()
        )
        if score:
            score.score = entry.score
        else:
            score = Score(
                student_id=student.id,
                course_id=course.id,
                unit_id=unit.id,
                score=entry.score,
            )
            db.add(score)

    db.commit()


# ============================================================
# 成绩查询
# ============================================================

@router.get("/course/{course_uuid}/my", response_model=ScoreMyOut)
def get_my_scores(
    course_uuid: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    course = _get_course_or_404(course_uuid, db)
    _require_course_member(course, current_user, db)

    units = db.query(Unit).filter(Unit.course_id == course.id).order_by(Unit.unit_order).all()

    student = db.query(Student).filter(Student.user_id == current_user.id).first()

    my_scores = []
    scores_list = []
    for u in units:
        if student:
            s = (
                db.query(Score)
                .filter(
                    Score.student_id == student.id,
                    Score.course_id == course.id,
                    Score.unit_id == u.id,
                )
                .first()
            )
            my_scores.append(MyScoreItem(unit_id=u.id, score=s.score if s else None))
            scores_list.append(s.score if s else None)
        else:
            my_scores.append(MyScoreItem(unit_id=u.id, score=None))
            scores_list.append(None)

    weighted_total = _calc_weighted_total(scores_list, units) if student else None

    return ScoreMyOut(
        course_name=course.name,
        units=[UnitOut.model_validate(u) for u in units],
        my_scores=my_scores,
        weighted_total=weighted_total,
    )


@router.get("/course/{course_uuid}/summary", response_model=ScoreSummaryOut)
def get_score_summary(
    course_uuid: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    course = _get_course_or_404(course_uuid, db)
    _require_course_teacher_or_admin(course, current_user)
    return _build_score_summary(course, db)


@router.get("/course/{course_uuid}/distribution", response_model=ScoreDistributionOut)
def get_score_distribution(
    course_uuid: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    course = _get_course_or_404(course_uuid, db)
    _require_course_teacher_or_admin(course, current_user)

    summary = _build_score_summary(course, db)

    bands_def = [
        ("90-100", 90, 101),
        ("80-89", 80, 90),
        ("70-79", 70, 80),
        ("60-69", 60, 70),
        ("0-59", 0, 60),
    ]

    band_counts = {name: 0 for name, _, _ in bands_def}
    totals = []
    passed = 0
    for rec in summary.students:
        if rec.weighted_total is not None:
            totals.append(rec.weighted_total)
            if rec.weighted_total >= 60:
                passed += 1
            for name, lo, hi in bands_def:
                if lo <= rec.weighted_total < hi:
                    band_counts[name] += 1
                    break

    total = len(totals)
    average = round(sum(totals) / total, 2) if total > 0 else 0.0
    sorted_totals = sorted(totals)
    n = len(sorted_totals)
    if n > 0:
        median = sorted_totals[n // 2] if n % 2 else (sorted_totals[n // 2 - 1] + sorted_totals[n // 2]) / 2
        median = round(median, 2)
    else:
        median = 0.0

    from schemas import ScoreBand

    return ScoreDistributionOut(
        bands=[ScoreBand(range=name, count=count) for name, count in band_counts.items()],
        total=total,
        average=average,
        median=median,
        passed=passed,
        failed=total - passed,
    )
