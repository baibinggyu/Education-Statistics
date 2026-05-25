from contextlib import asynccontextmanager

from fastapi import FastAPI

from database import Base, engine


@asynccontextmanager
async def lifespan(app: FastAPI):
    """应用启动时自动创建所有表（如果不存在）。"""
    Base.metadata.create_all(bind=engine)
    yield


app = FastAPI(
    title="Edu Server",
    version="0.1.0",
    description="AI + 音视频 + 实时互动 + 数据分析 综合教学平台后端",
    lifespan=lifespan,
)

# 路由注册
from routers import ai, announcements, attendance, auth, courses, files, messages, play_records, scores, users, videos

app.include_router(ai.router, prefix="/api/ai", tags=["ai"])
app.include_router(auth.router, prefix="/api/auth", tags=["auth"])
app.include_router(users.router, prefix="/api/users", tags=["users"])
app.include_router(courses.router, prefix="/api/courses", tags=["courses"])
# units 已挂载在 courses router 下
app.include_router(announcements.router, prefix="/api/courses", tags=["announcements"])
app.include_router(attendance.router, prefix="/api/courses", tags=["attendance"])
app.include_router(messages.router, prefix="/api/courses", tags=["messages"])
app.include_router(scores.router, prefix="/api/scores", tags=["scores"])
app.include_router(videos.router, prefix="/api/videos", tags=["videos"])
app.include_router(play_records.router, prefix="/api/play-records", tags=["play_records"])
app.include_router(files.router, prefix="/api/files", tags=["files"])


@app.get("/")
def root():
    return {
        "name": "Edu Server",
        "version": "0.1.0",
        "status": "running",
    }
