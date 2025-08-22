"""
AI Frame API - FastAPI backend for AR/VR content management
"""

from fastapi import FastAPI, HTTPException, UploadFile, File, Form, Body
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse, JSONResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel, Field
from typing import Optional, List, Dict, Any
from datetime import datetime
import json
import os
import uuid
import shutil
from pathlib import Path
import aiofiles
import base64

# Initialize FastAPI app
app = FastAPI(
    title="AI Frame API",
    description="Backend API for AR/VR object persistence and media management",
    version="1.0.0"
)

# Configure CORS for browser and XR access
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Allow all origins for development
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
    expose_headers=["X-Session-ID"]
)

# Base directory for data storage
DATA_DIR = Path("/workspaces/ai-frame/data")
DATA_DIR.mkdir(exist_ok=True)

# Mount static files
app.mount("/static", StaticFiles(directory="/workspaces/ai-frame/static"), name="static")

# ==================== Models ====================

class Position3D(BaseModel):
    x: float
    y: float
    z: float

class Rotation3D(BaseModel):
    x: float = 0
    y: float = 0
    z: float = 0
    w: float = 1  # Quaternion

class ARObject(BaseModel):
    id: str = Field(default_factory=lambda: str(uuid.uuid4()))
    type: str  # cube, sphere, cylinder, etc.
    position: Position3D
    rotation: Optional[Rotation3D] = None
    scale: Optional[float] = 1.0
    color: Optional[str] = "#00FF00"
    metadata: Optional[Dict[str, Any]] = {}
    created_at: datetime = Field(default_factory=datetime.now)

class Session(BaseModel):
    id: str = Field(default_factory=lambda: str(uuid.uuid4()))
    name: Optional[str] = None
    created_at: datetime = Field(default_factory=datetime.now)
    updated_at: datetime = Field(default_factory=datetime.now)
    objects: List[ARObject] = []
    metadata: Optional[Dict[str, Any]] = {}

class MediaUpload(BaseModel):
    session_id: str
    type: str  # image, video, audio
    filename: str
    metadata: Optional[Dict[str, Any]] = {}
    created_at: datetime = Field(default_factory=datetime.now)

# ==================== Helper Functions ====================

def get_session_dir(session_id: str) -> Path:
    """Get the directory path for a session"""
    session_dir = DATA_DIR / session_id
    session_dir.mkdir(exist_ok=True)
    return session_dir

def save_session_data(session_id: str, data: dict):
    """Save session data to JSON file"""
    session_dir = get_session_dir(session_id)
    session_file = session_dir / "session.json"
    with open(session_file, "w") as f:
        json.dump(data, f, indent=2, default=str)

def load_session_data(session_id: str) -> dict:
    """Load session data from JSON file"""
    session_file = get_session_dir(session_id) / "session.json"
    if not session_file.exists():
        raise HTTPException(status_code=404, detail="Session not found")
    with open(session_file, "r") as f:
        return json.load(f)

# ==================== Session Endpoints ====================

@app.post("/api/sessions", response_model=Session)
async def create_session(name: Optional[str] = None):
    """Create a new session"""
    session = Session(name=name)
    session_dir = get_session_dir(session.id)
    
    # Create subdirectories for media
    (session_dir / "images").mkdir(exist_ok=True)
    (session_dir / "videos").mkdir(exist_ok=True)
    (session_dir / "audio").mkdir(exist_ok=True)
    (session_dir / "objects").mkdir(exist_ok=True)
    
    # Save initial session data
    save_session_data(session.id, session.dict())
    
    return session

@app.get("/api/sessions/{session_id}", response_model=Session)
async def get_session(session_id: str):
    """Get session details"""
    data = load_session_data(session_id)
    return Session(**data)

@app.get("/api/sessions")
async def list_sessions():
    """List all sessions with summary info"""
    sessions = []
    for session_dir in DATA_DIR.iterdir():
        if session_dir.is_dir():
            session_file = session_dir / "session.json"
            if session_file.exists():
                with open(session_file, "r") as f:
                    session_data = json.load(f)
                
                # Add summary info
                objects_dir = session_dir / "objects"
                images_dir = session_dir / "images"
                audio_dir = session_dir / "audio"
                
                session_data["summary"] = {
                    "object_count": len(list(objects_dir.glob("*.json"))) if objects_dir.exists() else 0,
                    "image_count": len([f for f in images_dir.glob("*") if not f.suffix == ".json"]) if images_dir.exists() else 0,
                    "audio_count": len([f for f in audio_dir.glob("*") if not f.suffix == ".json"]) if audio_dir.exists() else 0,
                    "display_name": session_data.get("name") or f"Session {session_data['id'][:8]}..."
                }
                
                sessions.append(session_data)
    
    # Sort by created_at, newest first
    sessions.sort(key=lambda x: x.get("created_at", ""), reverse=True)
    return sessions

@app.delete("/api/sessions/{session_id}")
async def delete_session(session_id: str):
    """Delete a session and all its data"""
    session_dir = get_session_dir(session_id)
    if session_dir.exists():
        shutil.rmtree(session_dir)
        return {"message": "Session deleted successfully"}
    raise HTTPException(status_code=404, detail="Session not found")

# ==================== Object Endpoints ====================

@app.post("/api/sessions/{session_id}/objects", response_model=ARObject)
async def add_object(session_id: str, obj: ARObject):
    """Add an object to the session"""
    session_data = load_session_data(session_id)
    
    # Add object to session
    if "objects" not in session_data:
        session_data["objects"] = []
    session_data["objects"].append(obj.dict())
    session_data["updated_at"] = datetime.now().isoformat()
    
    # Save updated session
    save_session_data(session_id, session_data)
    
    # Also save object separately
    object_file = get_session_dir(session_id) / "objects" / f"{obj.id}.json"
    with open(object_file, "w") as f:
        json.dump(obj.dict(), f, indent=2, default=str)
    
    return obj

@app.get("/api/sessions/{session_id}/objects")
async def get_objects(session_id: str):
    """Get all objects in a session"""
    session_data = load_session_data(session_id)
    return session_data.get("objects", [])

@app.get("/api/sessions/{session_id}/objects/{object_id}")
async def get_object(session_id: str, object_id: str):
    """Get a specific object"""
    object_file = get_session_dir(session_id) / "objects" / f"{object_id}.json"
    if not object_file.exists():
        raise HTTPException(status_code=404, detail="Object not found")
    with open(object_file, "r") as f:
        return json.load(f)

@app.put("/api/sessions/{session_id}/objects/{object_id}")
async def update_object(session_id: str, object_id: str, obj: ARObject):
    """Update an object"""
    session_data = load_session_data(session_id)
    
    # Update object in session
    for i, existing_obj in enumerate(session_data.get("objects", [])):
        if existing_obj["id"] == object_id:
            session_data["objects"][i] = obj.dict()
            break
    else:
        raise HTTPException(status_code=404, detail="Object not found")
    
    session_data["updated_at"] = datetime.now().isoformat()
    save_session_data(session_id, session_data)
    
    # Update object file
    object_file = get_session_dir(session_id) / "objects" / f"{object_id}.json"
    with open(object_file, "w") as f:
        json.dump(obj.dict(), f, indent=2, default=str)
    
    return obj

@app.delete("/api/sessions/{session_id}/objects/{object_id}")
async def delete_object(session_id: str, object_id: str):
    """Delete an object"""
    session_data = load_session_data(session_id)
    
    # Remove from session
    session_data["objects"] = [
        obj for obj in session_data.get("objects", [])
        if obj["id"] != object_id
    ]
    session_data["updated_at"] = datetime.now().isoformat()
    save_session_data(session_id, session_data)
    
    # Delete object file
    object_file = get_session_dir(session_id) / "objects" / f"{object_id}.json"
    if object_file.exists():
        object_file.unlink()
    
    return {"message": "Object deleted successfully"}

# ==================== Image Endpoints ====================

@app.post("/api/sessions/{session_id}/images")
async def upload_image(
    session_id: str,
    file: Optional[UploadFile] = File(None),
    image_data: Optional[str] = Form(None),
    metadata: Optional[str] = Form("{}")
):
    """Upload an image (file or base64)"""
    session_dir = get_session_dir(session_id)
    images_dir = session_dir / "images"
    
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    
    if file:
        # Handle file upload
        filename = f"{timestamp}_{file.filename}"
        file_path = images_dir / filename
        
        async with aiofiles.open(file_path, "wb") as f:
            content = await file.read()
            await f.write(content)
    elif image_data:
        # Handle base64 data
        filename = f"{timestamp}_capture.png"
        file_path = images_dir / filename
        
        # Remove data URL prefix if present
        if "," in image_data:
            image_data = image_data.split(",")[1]
        
        # Decode and save
        image_bytes = base64.b64decode(image_data)
        async with aiofiles.open(file_path, "wb") as f:
            await f.write(image_bytes)
    else:
        raise HTTPException(status_code=400, detail="No image data provided")
    
    # Save metadata
    meta = json.loads(metadata) if isinstance(metadata, str) else metadata
    meta_file = images_dir / f"{filename}.json"
    with open(meta_file, "w") as f:
        json.dump({
            "filename": filename,
            "created_at": datetime.now().isoformat(),
            "metadata": meta
        }, f, indent=2)
    
    return {
        "filename": filename,
        "path": str(file_path),
        "metadata": meta
    }

@app.get("/api/sessions/{session_id}/images")
async def list_images(session_id: str):
    """List all images in a session"""
    images_dir = get_session_dir(session_id) / "images"
    images = []
    
    for image_file in images_dir.glob("*.png"):
        meta_file = images_dir / f"{image_file.name}.json"
        if meta_file.exists():
            with open(meta_file, "r") as f:
                images.append(json.load(f))
        else:
            images.append({"filename": image_file.name})
    
    for image_file in images_dir.glob("*.jpg"):
        meta_file = images_dir / f"{image_file.name}.json"
        if meta_file.exists():
            with open(meta_file, "r") as f:
                images.append(json.load(f))
        else:
            images.append({"filename": image_file.name})
    
    return images

@app.get("/api/sessions/{session_id}/images/{filename}")
async def get_image(session_id: str, filename: str):
    """Get an image file"""
    file_path = get_session_dir(session_id) / "images" / filename
    if not file_path.exists():
        raise HTTPException(status_code=404, detail="Image not found")
    return FileResponse(file_path)

# ==================== Video Endpoints ====================

@app.post("/api/sessions/{session_id}/videos")
async def upload_video(
    session_id: str,
    file: UploadFile = File(...),
    metadata: Optional[str] = Form("{}")
):
    """Upload a video file"""
    session_dir = get_session_dir(session_id)
    videos_dir = session_dir / "videos"
    
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    filename = f"{timestamp}_{file.filename}"
    file_path = videos_dir / filename
    
    async with aiofiles.open(file_path, "wb") as f:
        content = await file.read()
        await f.write(content)
    
    # Save metadata
    meta = json.loads(metadata) if isinstance(metadata, str) else metadata
    meta_file = videos_dir / f"{filename}.json"
    with open(meta_file, "w") as f:
        json.dump({
            "filename": filename,
            "created_at": datetime.now().isoformat(),
            "metadata": meta
        }, f, indent=2)
    
    return {
        "filename": filename,
        "path": str(file_path),
        "metadata": meta
    }

@app.get("/api/sessions/{session_id}/videos")
async def list_videos(session_id: str):
    """List all videos in a session"""
    videos_dir = get_session_dir(session_id) / "videos"
    videos = []
    
    for video_file in videos_dir.glob("*.mp4"):
        meta_file = videos_dir / f"{video_file.name}.json"
        if meta_file.exists():
            with open(meta_file, "r") as f:
                videos.append(json.load(f))
        else:
            videos.append({"filename": video_file.name})
    
    for video_file in videos_dir.glob("*.webm"):
        meta_file = videos_dir / f"{video_file.name}.json"
        if meta_file.exists():
            with open(meta_file, "r") as f:
                videos.append(json.load(f))
        else:
            videos.append({"filename": video_file.name})
    
    return videos

@app.get("/api/sessions/{session_id}/videos/{filename}")
async def get_video(session_id: str, filename: str):
    """Get a video file"""
    file_path = get_session_dir(session_id) / "videos" / filename
    if not file_path.exists():
        raise HTTPException(status_code=404, detail="Video not found")
    return FileResponse(file_path)

# ==================== Audio Endpoints ====================

@app.post("/api/sessions/{session_id}/audio")
async def upload_audio(
    session_id: str,
    file: Optional[UploadFile] = File(None),
    audio_data: Optional[str] = Form(None),
    metadata: Optional[str] = Form("{}")
):
    """Upload an audio file or base64 data"""
    session_dir = get_session_dir(session_id)
    audio_dir = session_dir / "audio"
    
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    
    if file:
        # Handle file upload
        filename = f"{timestamp}_{file.filename}"
        file_path = audio_dir / filename
        
        async with aiofiles.open(file_path, "wb") as f:
            content = await file.read()
            await f.write(content)
    elif audio_data:
        # Handle base64 data
        filename = f"{timestamp}_recording.webm"
        file_path = audio_dir / filename
        
        # Remove data URL prefix if present
        if "," in audio_data:
            audio_data = audio_data.split(",")[1]
        
        # Decode and save
        audio_bytes = base64.b64decode(audio_data)
        async with aiofiles.open(file_path, "wb") as f:
            await f.write(audio_bytes)
    else:
        raise HTTPException(status_code=400, detail="No audio data provided")
    
    # Save metadata
    meta = json.loads(metadata) if isinstance(metadata, str) else metadata
    meta_file = audio_dir / f"{filename}.json"
    with open(meta_file, "w") as f:
        json.dump({
            "filename": filename,
            "created_at": datetime.now().isoformat(),
            "metadata": meta
        }, f, indent=2)
    
    return {
        "filename": filename,
        "path": str(file_path),
        "metadata": meta
    }

@app.get("/api/sessions/{session_id}/audio")
async def list_audio(session_id: str):
    """List all audio files in a session"""
    audio_dir = get_session_dir(session_id) / "audio"
    audio_files = []
    
    for audio_file in audio_dir.glob("*"):
        if not audio_file.suffix == ".json":
            meta_file = audio_dir / f"{audio_file.name}.json"
            if meta_file.exists():
                with open(meta_file, "r") as f:
                    audio_files.append(json.load(f))
            else:
                audio_files.append({"filename": audio_file.name})
    
    return audio_files

@app.get("/api/sessions/{session_id}/audio/{filename}")
async def get_audio(session_id: str, filename: str):
    """Get an audio file"""
    file_path = get_session_dir(session_id) / "audio" / filename
    if not file_path.exists():
        raise HTTPException(status_code=404, detail="Audio file not found")
    return FileResponse(file_path)

# ==================== Health & Status ====================

@app.get("/")
async def root():
    """Root endpoint"""
    return {
        "name": "AI Frame API",
        "version": "1.0.0",
        "status": "running",
        "endpoints": {
            "api_docs": "/docs",
            "browser_interface": "/static/index.html",
            "xr_interface": "/static/xr.html"
        }
    }

@app.get("/api/health")
async def health_check():
    """Health check endpoint"""
    return {
        "status": "healthy",
        "timestamp": datetime.now().isoformat(),
        "data_dir": str(DATA_DIR),
        "sessions_count": len(list(DATA_DIR.iterdir()))
    }

if __name__ == "__main__":
    import uvicorn
    # Detect if running in Codespaces
    codespaces = os.environ.get("CODESPACES") == "true"
    
    if codespaces:
        print(f"Running in GitHub Codespaces")
        print(f"Codespace Name: {os.environ.get('CODESPACE_NAME')}")
        print(f"API will be available at: https://{os.environ.get('CODESPACE_NAME')}-8000.{os.environ.get('GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN', 'app.github.dev')}")
    
    uvicorn.run(app, host="0.0.0.0", port=8000, reload=True)