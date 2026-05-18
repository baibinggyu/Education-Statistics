from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from sqlalchemy.orm import Session
from jose import JWTError

from database import get_db
from models import Course, CourseMember, User
from security import decode_access_token

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/api/auth/login")


def get_current_user(
    token: str = Depends(oauth2_scheme),
    db: Session = Depends(get_db),
) -> User:
    """从 JWT 中解析当前登录用户。

    返回 SQLAlchemy User 对象（含 BIGINT id），后续依赖和业务逻辑都用 id 做查询。
    """
    try:
        payload = decode_access_token(token)
        user_uuid = payload.get("sub")
        if user_uuid is None:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid token: missing subject",
            )
    except JWTError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid token",
        )

    user = db.query(User).filter(User.uuid == user_uuid).first()
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User not found",
        )

    if user.status != 1:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="User is disabled",
        )

    return user


def require_teacher_or_admin(
    user: User = Depends(get_current_user),
) -> User:
    """仅允许教师和管理员。"""
    if user.role not in ("teacher", "admin"):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Permission denied: teacher or admin only",
        )
    return user


def require_admin(
    user: User = Depends(get_current_user),
) -> User:
    """仅允许管理员。"""
    if user.role != "admin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Permission denied: admin only",
        )
    return user


def require_course_member(
    course_uuid: str,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> Course:
    """验证当前用户是否属于指定课程，返回 Course 对象。

    用法（在路由函数参数中）:
        course: Course = Depends(require_course_member)

    由于需要从路径中获取 course_uuid，实际使用时需配合 lambda 包装:
        def require_member(course_uuid: str):
            def _dep(db: Session = Depends(get_db), user: User = Depends(get_current_user)):
                ...
            return _dep

    简化版: 路由内手动调用 get_course_with_access_check()
    """
    course = db.query(Course).filter(
        Course.uuid == course_uuid,
        Course.status != "deleted",
    ).first()

    if course is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Course not found",
        )

    if user.role == "admin":
        return course

    member = db.query(CourseMember).filter(
        CourseMember.course_id == course.id,
        CourseMember.user_id == user.id,
    ).first()

    if member is None:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You are not a member of this course",
        )

    return course


def require_course_teacher(
    course_uuid: str,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> Course:
    """验证当前用户是指定课程的教师（或管理员），返回 Course 对象。"""
    course = db.query(Course).filter(
        Course.uuid == course_uuid,
        Course.status != "deleted",
    ).first()

    if course is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Course not found",
        )

    if user.role == "admin":
        return course

    if course.teacher_id != user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only the course teacher can perform this action",
        )

    return course
