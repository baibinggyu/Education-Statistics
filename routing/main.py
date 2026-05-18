from fastapi import FastAPI, HTTPException, APIRouter
from fastapi.responses import FileResponse
from pathlib import Path
import uvicorn
from pydantic import BaseModel
VIDEO_MIME_MAP = {
    ".mp4": "video/mp4",
    ".avi": "video/x-msvideo",
    ".mov": "video/quicktime",
    ".mkv": "video/x-matroska",
    ".webm": "video/webm",
    ".flv": "video/x-flv",
}
app = FastAPI()
router = APIRouter()


@app.get("/")
def root():

    return {"message": "Hello from FastAPI root"}


@app.get("/source/edu/{filename:path}")
def get_source_edu(filename: str):
    file_path = Path(f"source/edu/{filename}")
    if not file_path.exists():
        raise HTTPException(status_code=404, detail="FILE NOT FOUND")
    ext = file_path.suffix.lower()
    ret_media_type = VIDEO_MIME_MAP.get(ext, "application/octet-stream")
    return FileResponse(file_path, media_type=ret_media_type)


if __name__ == "__main__":
    uvicorn.run("main:app", host="localhost", port=11111, reload=True)
