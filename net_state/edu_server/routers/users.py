from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from database import get_db
from deps import get_current_user
from models import Student, User
from schemas import StudentBind, StudentBriefOut, UserMeOut, UserUpdate

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
