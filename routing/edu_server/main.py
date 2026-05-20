from fastapi import FastAPI, HTTPException
from fastapi.responses import FileResponse
from pathlib import Path
from .database import engine, Base
from .routers import auth, users, courses, videos, play_records

VIDEO_MIME_MAP = {
    ".mp4": "video/mp4",
    ".avi": "video/x-msvideo",
    ".mov": "video/quicktime",
    ".mkv": "video/x-matroska",
    ".webm": "video/webm",
    ".flv": "video/x-flv",
}

# Create all tables on startup (safe if tables already exist)
Base.metadata.create_all(bind=engine)

app = FastAPI(title="Edu Server", version="0.1.0")

# Include API routers
app.include_router(auth.router)
app.include_router(users.router)
app.include_router(courses.router)
app.include_router(videos.router)
app.include_router(play_records.router)


@app.get("/")
def root():
    return {"name": "Edu Server", "status": "running"}


@app.get("/source/edu/{filename:path}")
def get_source_edu(filename: str):
    file_path = Path(f"source/edu/{filename}")
    if not file_path.is_file():
        raise HTTPException(status_code=404, detail="FILE NOT FOUND")
    ext = file_path.suffix.lower()
    ret_media_type = VIDEO_MIME_MAP.get(ext, "application/octet-stream")
    return FileResponse(file_path, media_type=ret_media_type)
