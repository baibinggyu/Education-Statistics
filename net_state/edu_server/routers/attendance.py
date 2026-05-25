"""考勤/点名管理路由。

教师发起签到（roll call），对学生进行出勤标记。
"""

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from database import get_db
from deps import get_current_user, require_teacher_or_admin
from models import (
    Attendance,
    AttendanceRecord,
    Course,
    CourseMember,
    Student,
    User,
)
from schemas import (
    AttendanceCreate,
    AttendanceDetailOut,
    AttendanceMark,
    AttendanceOut,
    AttendanceRecordOut,
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
            detail="Only the course teacher can manage attendance",
        )


def _require_course_member_or_admin(course: Course, user: User, db: Session):
    """确认用户是课程成员或管理员，否则 403。"""
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


def _build_attendance_out(att: Attendance, db: Session) -> dict:
    """构建 AttendanceOut / AttendanceDetailOut 的公共字段。"""
    records = db.query(AttendanceRecord).filter(
        AttendanceRecord.attendance_id == att.id
    ).all()

    total = len(records)
    present_count = sum(1 for r in records if r.status == "present")
    absent_count = sum(1 for r in records if r.status == "absent")
    late_count = sum(1 for r in records if r.status == "late")
    leave_count = sum(1 for r in records if r.status == "leave")

    creator = db.query(User).filter(User.id == att.created_by).first()
    creator_name = creator.username if creator else "unknown"

    course = db.query(Course).filter(Course.id == att.course_id).first()

    return {
        "course_uuid": course.uuid if course else "",
        "created_by_name": creator_name,
        "total": total,
        "present_count": present_count,
        "absent_count": absent_count,
        "late_count": late_count,
        "leave_count": leave_count,
    }


def _build_record_out(record: AttendanceRecord, db: Session) -> AttendanceRecordOut:
    student_user = db.query(User).filter(User.id == record.student_id).first()
    student = db.query(Student).filter(Student.user_id == record.student_id).first()

    return AttendanceRecordOut(
        student_uuid=student_user.uuid if student_user else "",
        student_name=student_user.username if student_user else "",
        student_no=student.student_no if student else None,
        real_name=student.real_name if student else None,
        status=record.status or "present",
        note=record.note,
        created_at=record.created_at,
    )


# ============================================================
# 发起签到（创建考勤会话）
# ============================================================

@router.post(
    "/{course_uuid}/attendance",
    response_model=AttendanceDetailOut,
    status_code=status.HTTP_201_CREATED,
)
def start_attendance(
    course_uuid: str,
    data: AttendanceCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_teacher_or_admin),
):
    course = _get_course_or_404(course_uuid, db)
    _require_course_teacher_or_admin(course, current_user)

    attendance = Attendance(
        course_id=course.id,
        created_by=current_user.id,
        title=data.title,
    )
    db.add(attendance)
    db.flush()  # 获取 attendance.id

    # 自动为课程所有学生创建记录，默认状态 absent
    student_members = (
        db.query(CourseMember)
        .filter(CourseMember.course_id == course.id, CourseMember.member_role == "student")
        .all()
    )
    for sm in student_members:
        record = AttendanceRecord(
            attendance_id=attendance.id,
            student_id=sm.user_id,
            status="absent",
        )
        db.add(record)

    db.commit()
    db.refresh(attendance)

    info = _build_attendance_out(attendance, db)
    records = db.query(AttendanceRecord).filter(
        AttendanceRecord.attendance_id == attendance.id
    ).all()

    return AttendanceDetailOut(
        uuid=attendance.uuid,
        title=attendance.title,
        status=attendance.status or "open",
        records=[_build_record_out(r, db) for r in records],
        created_at=attendance.created_at,
        closed_at=attendance.closed_at,
        **info,
    )


# ============================================================
# 列出课程的考勤会话
# ============================================================

@router.get("/{course_uuid}/attendance", response_model=list[AttendanceOut])
def list_attendances(
    course_uuid: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    course = _get_course_or_404(course_uuid, db)
    _require_course_member_or_admin(course, current_user, db)

    attendances = (
        db.query(Attendance)
        .filter(Attendance.course_id == course.id)
        .order_by(Attendance.created_at.desc())
        .all()
    )

    result = []
    for att in attendances:
        info = _build_attendance_out(att, db)
        result.append(
            AttendanceOut(
                uuid=att.uuid,
                title=att.title,
                status=att.status or "open",
                created_at=att.created_at,
                closed_at=att.closed_at,
                **info,
            )
        )
    return result


# ============================================================
# 查看考勤详情（含所有学生记录）
# ============================================================

@router.get(
    "/{course_uuid}/attendance/{attendance_uuid}",
    response_model=AttendanceDetailOut,
)
def get_attendance_detail(
    course_uuid: str,
    attendance_uuid: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    course = _get_course_or_404(course_uuid, db)
    _require_course_member_or_admin(course, current_user, db)

    attendance = (
        db.query(Attendance)
        .filter(Attendance.uuid == attendance_uuid, Attendance.course_id == course.id)
        .first()
    )
    if attendance is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Attendance session not found",
        )

    info = _build_attendance_out(attendance, db)
    records = db.query(AttendanceRecord).filter(
        AttendanceRecord.attendance_id == attendance.id
    ).all()

    return AttendanceDetailOut(
        uuid=attendance.uuid,
        title=attendance.title,
        status=attendance.status or "open",
        records=[_build_record_out(r, db) for r in records],
        created_at=attendance.created_at,
        closed_at=attendance.closed_at,
        **info,
    )


# ============================================================
# 标记学生出勤状态
# ============================================================

@router.put("/{course_uuid}/attendance/{attendance_uuid}/mark")
def mark_attendance(
    course_uuid: str,
    attendance_uuid: str,
    data: AttendanceMark,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_teacher_or_admin),
):
    course = _get_course_or_404(course_uuid, db)
    _require_course_teacher_or_admin(course, current_user)

    attendance = (
        db.query(Attendance)
        .filter(Attendance.uuid == attendance_uuid, Attendance.course_id == course.id)
        .first()
    )
    if attendance is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Attendance session not found",
        )

    if attendance.status == "closed":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Attendance session is already closed",
        )

    # 查找学生用户
    student_user = db.query(User).filter(User.uuid == data.student_uuid).first()
    if student_user is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Student not found",
        )

    record = (
        db.query(AttendanceRecord)
        .filter(
            AttendanceRecord.attendance_id == attendance.id,
            AttendanceRecord.student_id == student_user.id,
        )
        .first()
    )
    if record is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Student is not in this attendance session",
        )

    record.status = data.status
    if data.note is not None:
        record.note = data.note

    db.commit()
    db.refresh(record)

    return _build_record_out(record, db)


# ============================================================
# 批量标记（可选：一次性标记多人）
# ============================================================

@router.put("/{course_uuid}/attendance/{attendance_uuid}/mark-batch")
def batch_mark_attendance(
    course_uuid: str,
    attendance_uuid: str,
    data: list[AttendanceMark],
    db: Session = Depends(get_db),
    current_user: User = Depends(require_teacher_or_admin),
):
    course = _get_course_or_404(course_uuid, db)
    _require_course_teacher_or_admin(course, current_user)

    attendance = (
        db.query(Attendance)
        .filter(Attendance.uuid == attendance_uuid, Attendance.course_id == course.id)
        .first()
    )
    if attendance is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Attendance session not found",
        )

    if attendance.status == "closed":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Attendance session is already closed",
        )

    results = []
    for mark in data:
        student_user = db.query(User).filter(User.uuid == mark.student_uuid).first()
        if student_user is None:
            continue

        record = (
            db.query(AttendanceRecord)
            .filter(
                AttendanceRecord.attendance_id == attendance.id,
                AttendanceRecord.student_id == student_user.id,
            )
            .first()
        )
        if record is None:
            continue

        record.status = mark.status
        if mark.note is not None:
            record.note = mark.note
        results.append(record)

    db.commit()
    return {"marked": len(results)}


# ============================================================
# 关闭签到
# ============================================================

@router.put("/{course_uuid}/attendance/{attendance_uuid}/close")
def close_attendance(
    course_uuid: str,
    attendance_uuid: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_teacher_or_admin),
):
    course = _get_course_or_404(course_uuid, db)
    _require_course_teacher_or_admin(course, current_user)

    attendance = (
        db.query(Attendance)
        .filter(Attendance.uuid == attendance_uuid, Attendance.course_id == course.id)
        .first()
    )
    if attendance is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Attendance session not found",
        )

    if attendance.status == "closed":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Attendance session is already closed",
        )

    from datetime import datetime as dt

    attendance.status = "closed"
    attendance.closed_at = dt.now()

    db.commit()
    db.refresh(attendance)

    return {
        "uuid": attendance.uuid,
        "status": attendance.status,
        "closed_at": attendance.closed_at.isoformat() if attendance.closed_at else None,
    }


# ============================================================
# 删除考勤会话
# ============================================================

@router.delete("/{course_uuid}/attendance/{attendance_uuid}", status_code=status.HTTP_204_NO_CONTENT)
def delete_attendance(
    course_uuid: str,
    attendance_uuid: str,
    db: Session = Depends(get_db),
    current_user: User = Depends(require_teacher_or_admin),
):
    course = _get_course_or_404(course_uuid, db)
    _require_course_teacher_or_admin(course, current_user)

    attendance = (
        db.query(Attendance)
        .filter(Attendance.uuid == attendance_uuid, Attendance.course_id == course.id)
        .first()
    )
    if attendance is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Attendance session not found",
        )

    # 先删除关联记录
    db.query(AttendanceRecord).filter(
        AttendanceRecord.attendance_id == attendance.id
    ).delete()

    db.delete(attendance)
    db.commit()
