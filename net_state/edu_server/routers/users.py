from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from database import get_db
from deps import get_current_user
from models import Student, User
from schemas import StudentBriefOut, UserMeOut, UserUpdate

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
