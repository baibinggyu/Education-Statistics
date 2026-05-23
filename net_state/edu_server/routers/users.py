from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from database import get_db
from deps import get_current_user, require_admin
from models import Student, User
from schemas import StudentBind, StudentBindWithUuid, StudentBriefOut, UserMeOut, UserUpdate

router = APIRouter()


@router.get("/me", response_model=UserMeOut)
def get_me(
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """获取当前登录用户信息。

    如果是 student 角色，附带学生档案（学号、姓名）。
    """
    result = UserMeOut.model_validate(current_user)

    if current_user.role == "student":
        student = (
            db.query(Student).filter(Student.user_id == current_user.id).first()
        )
        if student:
            result.student = StudentBriefOut.model_validate(student)

    return result


@router.patch("/me", response_model=UserMeOut)
def update_me(
    data: UserUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """更新当前用户信息（目前仅支持修改用户名）。"""
    if data.username is not None:
        exists = (
            db.query(User)
            .filter(User.username == data.username, User.id != current_user.id)
            .first()
        )
        if exists:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="Username already taken",
            )
        current_user.username = data.username
        db.commit()
        db.refresh(current_user)

    return get_me(db=db, current_user=current_user)


@router.post("/bind", response_model=UserMeOut, status_code=status.HTTP_201_CREATED)
def bind_student(
    data: StudentBind,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    """将当前用户绑定为学生档案（创建 Student 记录）。

    仅限 role=student 的用户。如果已绑定则更新。
    """
    if current_user.role != "student":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Only students can bind a student profile",
        )

    # 检查学号唯一性
    dup = db.query(Student).filter(
        Student.student_no == data.student_no,
        Student.user_id != current_user.id,
    ).first()
    if dup:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Student number already taken",
        )

    student = db.query(Student).filter(Student.user_id == current_user.id).first()
    if student:
        student.student_no = data.student_no
        student.real_name = data.real_name
    else:
        student = Student(
            user_id=current_user.id,
            student_no=data.student_no,
            real_name=data.real_name,
        )
        db.add(student)

    db.commit()
    db.refresh(student)

    return get_me(db=db, current_user=current_user)


# ============================================================
# Admin: 为学生设置学籍信息
# ============================================================

@router.put("/admin/student-profile")
def admin_batch_set_student_profile(
    data: list[StudentBindWithUuid],
    db: Session = Depends(get_db),
    current_user: User = Depends(require_admin),
):
    """管理员批量设置用户的学生档案（学号、姓名）。"""
    results = []
    for item in data:
        user = db.query(User).filter(User.uuid == item.user_uuid).first()
        if not user:
            results.append({"user_uuid": item.user_uuid, "status": "user not found"})
            continue

        # 检查学号唯一性（排除当前用户）
        dup = db.query(Student).filter(
            Student.student_no == item.student_no,
            Student.user_id != user.id,
        ).first()
        if dup:
            results.append({"user_uuid": item.user_uuid, "status": "student_no conflict"})
            continue

        student = db.query(Student).filter(Student.user_id == user.id).first()
        if student:
            student.student_no = item.student_no
            student.real_name = item.real_name
        else:
            student = Student(
                user_id=user.id,
                student_no=item.student_no,
                real_name=item.real_name,
            )
            db.add(student)
        results.append({"user_uuid": item.user_uuid, "status": "ok"})

    db.commit()
    return {"results": results}
