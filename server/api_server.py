#!/usr/bin/env python3
"""
AI Frame API Server
Central hub for receiving, processing, and forwarding captured media
"""

import os
import json
import uuid
import asyncio
import hashlib
from datetime import datetime
from pathlib import Path
from typing import List, Optional, Dict, Any
import logging

from fastapi import FastAPI, File, UploadFile, Form, HTTPException, BackgroundTasks
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse, FileResponse
from fastapi.staticfiles import StaticFiles
import uvicorn
import aiofiles
import httpx
from pydantic import BaseModel, Field

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Initialize FastAPI app
app = FastAPI(
    title="AI Frame Processing Server",
    description="Captures and processes media from AR/VR and mobile devices",
    version="1.0.0"
)

# Configure CORS for all origins (adjust for production)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
    expose_headers=["*"]
)

# Add request logging middleware
@app.middleware("http")
async def log_requests(request, call_next):
    logger.info(f"Request: {request.method} {request.url.path}")
    response = await call_next(request)
    logger.info(f"Response: {response.status_code}")
    return response

# Configuration
class Config:
    UPLOAD_DIR = Path("./uploads")
    SESSIONS_DIR = Path("./sessions")  # New sessions directory
    PROCESSED_DIR = Path("./processed")
    MAX_FILE_SIZE = 100 * 1024 * 1024  # 100MB
    FORWARD_APIS = []  # External APIs to forward to
    ENABLE_AI_PROCESSING = False
    STORAGE_DAYS = 7  # Days to keep files

config = Config()

# Ensure directories exist
config.UPLOAD_DIR.mkdir(exist_ok=True)
config.SESSIONS_DIR.mkdir(exist_ok=True)
config.PROCESSED_DIR.mkdir(exist_ok=True)

# Data models
class CaptureMetadata(BaseModel):
    id: str = Field(default_factory=lambda: str(uuid.uuid4()))
    timestamp: datetime = Field(default_factory=datetime.now)
    source: str  # "webxr", "mobile", "desktop"
    device: str
    session_id: Optional[str] = None
    location: Optional[Dict[str, float]] = None  # lat, lon

class ProcessedObject(BaseModel):
    id: str
    type: str  # "text", "image", "model", "audio"
    content: Optional[str] = None
    url: Optional[str] = None
    position: Optional[Dict[str, float]] = None
    metadata: Dict[str, Any] = {}

class CaptureSession:
    """Manages capture sessions across devices"""
    def __init__(self):
        self.sessions = {}
        self.captures = []
        
    def create_session(self, device_id: str) -> str:
        session_id = str(uuid.uuid4())
        self.sessions[session_id] = {
            "device_id": device_id,
            "created": datetime.now(),
            "captures": []
        }
        return session_id
    
    def add_capture(self, session_id: str, capture_id: str):
        if session_id in self.sessions:
            self.sessions[session_id]["captures"].append(capture_id)
        self.captures.append({
            "id": capture_id,
            "session_id": session_id,
            "timestamp": datetime.now()
        })

# Global session manager
session_manager = CaptureSession()

# Utility functions
async def save_upload_file(upload_file: UploadFile, session_folder: Path, prefix: str = "") -> Path:
    """Save uploaded file to session folder"""
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    file_id = str(uuid.uuid4())[:8]
    extension = Path(upload_file.filename).suffix
    
    # Ensure session folder exists
    session_folder.mkdir(parents=True, exist_ok=True)
    
    # Create filename with optional prefix
    if prefix:
        filename = f"{prefix}_{timestamp}_{file_id}{extension}"
    else:
        filename = f"{timestamp}_{file_id}{extension}"
    
    filepath = session_folder / filename
    
    async with aiofiles.open(filepath, 'wb') as f:
        content = await upload_file.read()
        await f.write(content)
    
    logger.info(f"Saved file: {filepath}")
    return filepath

async def forward_to_apis(data: Dict, files: List[Path]):
    """Forward captured data to configured external APIs"""
    if not config.FORWARD_APIS:
        return
    
    async with httpx.AsyncClient() as client:
        for api_url in config.FORWARD_APIS:
            try:
                # Prepare multipart data
                files_data = []
                for filepath in files:
                    files_data.append(
                        ('files', (filepath.name, open(filepath, 'rb'), 'application/octet-stream'))
                    )
                
                response = await client.post(
                    api_url,
                    data=data,
                    files=files_data,
                    timeout=30.0
                )
                logger.info(f"Forwarded to {api_url}: {response.status_code}")
            except Exception as e:
                logger.error(f"Failed to forward to {api_url}: {e}")

def process_media_local(filepath: Path, media_type: str) -> Dict:
    """Process media locally (placeholder for AI processing)"""
    # This is where you'd add actual AI processing
    # For now, return mock results
    return {
        "analysis": f"Processed {media_type}",
        "filepath": str(filepath),
        "size": filepath.stat().st_size,
        "type": media_type
    }

# API Endpoints

@app.get("/")
async def root():
    """API information"""
    logger.info("Root endpoint accessed")
    return {
        "name": "AI Frame Processing Server",
        "version": "1.0.0",
        "endpoints": {
            "upload": "/upload",
            "status": "/status",
            "session": "/session/create",
            "captures": "/captures",
            "download": "/download/{capture_id}"
        }
    }

@app.post("/upload")
async def upload_media(
    background_tasks: BackgroundTasks,
    source: str = Form("unknown"),
    device: str = Form("unknown"),
    timestamp: Optional[str] = Form(None),
    text: Optional[str] = Form(None),
    session_id: Optional[str] = Form(None),
    capture_type: Optional[str] = Form(None),
    metadata: Optional[str] = Form(None),
    video: Optional[UploadFile] = File(None),
    audio: Optional[UploadFile] = File(None),
    image: Optional[UploadFile] = File(None)
):
    """Main upload endpoint for all capture devices"""
    
    capture_id = str(uuid.uuid4())
    
    # Generate session_id if not provided
    if not session_id:
        session_id = f"{source}_{datetime.now().strftime('%Y%m%d_%H%M%S')}_{str(uuid.uuid4())[:8]}"
        # Create session in manager
        session_manager.sessions[session_id] = {
            "device_id": device,
            "created": datetime.now(),
            "captures": []
        }
    
    logger.info(f"New upload - ID: {capture_id}, Source: {source}, Type: {capture_type or 'generic'}, Session: {session_id}")
    
    # Create metadata with additional capture info
    metadata_dict = {
        "id": capture_id,
        "source": source,
        "device": device,
        "session_id": session_id,
        "timestamp": datetime.now().isoformat(),
        "capture_type": capture_type
    }
    
    # Parse additional metadata if provided
    if metadata:
        try:
            additional_metadata = json.loads(metadata)
            metadata_dict.update(additional_metadata)
        except:
            pass
    
    metadata_obj = CaptureMetadata(
        id=capture_id,
        source=source,
        device=device,
        session_id=session_id
    )
    
    # Save files
    saved_files = []
    results = {}
    
    try:
        # Create session folder path
        session_folder = config.SESSIONS_DIR / session_id
        session_folder.mkdir(parents=True, exist_ok=True)
        
        # Process each media type
        if video:
            filepath = await save_upload_file(video, session_folder, "video")
            saved_files.append(filepath)
            results["video"] = process_media_local(filepath, "video")
            
        if audio:
            filepath = await save_upload_file(audio, session_folder, "audio")
            saved_files.append(filepath)
            results["audio"] = process_media_local(filepath, "audio")
            
        if image:
            filepath = await save_upload_file(image, session_folder, "screenshot")
            saved_files.append(filepath)
            results["image"] = process_media_local(filepath, "image")
            
        if text:
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            text_path = session_folder / f"text_{timestamp}.txt"
            async with aiofiles.open(text_path, 'w') as f:
                await f.write(text)
            results["text"] = {"content": text, "length": len(text)}
        
        # Save metadata for this capture
        metadata_path = session_folder / f"metadata_{capture_id}.json"
        async with aiofiles.open(metadata_path, 'w') as f:
            await f.write(json.dumps(metadata_dict, indent=2))
        
        # Add to session if provided
        if session_id:
            session_manager.add_capture(session_id, capture_id)
        
        # Forward to external APIs in background
        if config.FORWARD_APIS:
            background_tasks.add_task(
                forward_to_apis,
                {"capture_id": capture_id, "metadata": metadata.dict()},
                saved_files
            )
        
        # Generate AR objects for response
        objects = []
        
        # Create response object based on what was uploaded
        if any([video, audio, image, text]):
            objects.append(ProcessedObject(
                id=f"response_{capture_id}",
                type="text",
                content=f"Capture {capture_id[:8]} received: " + 
                       ", ".join([k for k in results.keys()]),
                position={"x": 0, "y": 1.5, "z": -2}
            ))
        
        return JSONResponse({
            "success": True,
            "capture_id": capture_id,
            "results": results,
            "objects": [obj.dict() for obj in objects],
            "session_id": session_id
        })
        
    except Exception as e:
        logger.error(f"Upload failed: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/session/create")
async def create_session(device_id: str = Form(...)):
    """Create a new capture session"""
    session_id = session_manager.create_session(device_id)
    return {
        "session_id": session_id,
        "device_id": device_id,
        "created": datetime.now().isoformat()
    }

@app.get("/sessions")
async def list_sessions():
    """List all sessions with their metadata"""
    logger.info("Sessions endpoint accessed")
    sessions_list = []
    
    for session_id, session_data in session_manager.sessions.items():
        sessions_list.append({
            "session_id": session_id,
            "device_id": session_data["device_id"],
            "created_at": session_data["created"].isoformat(),
            "captures_count": len(session_data["captures"])
        })
    
    return {"sessions": sessions_list}

@app.get("/sessions/{session_id}")
async def get_session_details(session_id: str):
    """Get detailed information about a specific session"""
    logger.info(f"Session details requested for: {session_id}")
    
    if session_id not in session_manager.sessions:
        raise HTTPException(status_code=404, detail="Session not found")
    
    session_data = session_manager.sessions[session_id]
    files = []
    
    # List files for this session
    session_dir = config.SESSIONS_DIR / session_id
    if session_dir.exists():
        for file_path in session_dir.rglob("*"):
            if file_path.is_file() and not file_path.name.startswith("metadata_"):
                files.append({
                    "filename": file_path.name,
                    "size": file_path.stat().st_size,
                    "modified": datetime.fromtimestamp(file_path.stat().st_mtime).isoformat()
                })
    
    return {
        "session": {
            "session_id": session_id,
            "device_id": session_data["device_id"],
            "created_at": session_data["created"].isoformat(),
            "media_files": files
        },
        "files": files
    }

@app.delete("/sessions/{session_id}")
async def delete_session(session_id: str):
    """Delete a session and its files"""
    logger.info(f"Delete session requested for: {session_id}")
    
    if session_id in session_manager.sessions:
        del session_manager.sessions[session_id]
    
    # Delete session folder
    session_dir = config.SESSIONS_DIR / session_id
    if session_dir.exists():
        import shutil
        shutil.rmtree(session_dir)
    
    return {"status": "deleted", "session_id": session_id}

@app.get("/media/{session_id}/{filename}")
async def get_media_file(session_id: str, filename: str):
    """Get a specific media file"""
    logger.info(f"Media file requested: {session_id}/{filename}")
    
    # Search for the file in session folder
    file_path = config.SESSIONS_DIR / session_id / filename
    if file_path.exists():
        return FileResponse(file_path)
    
    raise HTTPException(status_code=404, detail="File not found")

@app.get("/captures")
async def list_captures(session_id: Optional[str] = None, limit: int = 50):
    """List recent captures"""
    captures = session_manager.captures[-limit:]
    
    if session_id and session_id in session_manager.sessions:
        session_captures = session_manager.sessions[session_id]["captures"]
        captures = [c for c in captures if c["id"] in session_captures]
    
    return {
        "captures": captures,
        "total": len(captures)
    }

@app.get("/objects/{session_id}")
async def get_session_objects(session_id: str):
    """Get all placed objects for a session to restore AR state"""
    logger.info(f"Retrieving objects for session: {session_id}")
    
    objects = []
    
    # Search in the session directory
    session_dir = config.SESSIONS_DIR / session_id
    
    if session_dir.exists():
        # Look for text files in the session directory
        for capture_dir in [session_dir]:
            if capture_dir.is_dir():
                # Check if there's a text file with object data
                text_file = capture_dir / "text.txt"
                metadata_file = capture_dir / "metadata.json"
                
                if text_file.exists():
                    try:
                        with open(text_file, 'r') as f:
                            content = f.read()
                            
                        # Try to parse as JSON (object placement data)
                        import json
                        try:
                            data = json.loads(content)
                            # Check if this is object placement data
                            if 'type' in data and 'position' in data:
                                # Check if this belongs to the session
                                if metadata_file.exists():
                                    with open(metadata_file, 'r') as mf:
                                        metadata = json.loads(mf.read())
                                        if metadata.get('session_id') == session_id:
                                            objects.append(data)
                                # Also check if session_id is in the content
                                elif 'session_id' in data and data['session_id'] == session_id:
                                    objects.append(data)
                        except json.JSONDecodeError:
                            # Not JSON, might be plain text
                            pass
                    except Exception as e:
                        logger.error(f"Error reading object data: {e}")
    
    # Sort by timestamp if available
    objects.sort(key=lambda x: x.get('timestamp', 0))
    
    logger.info(f"Found {len(objects)} objects for session {session_id}")
    
    return {
        "session_id": session_id,
        "objects": objects,
        "count": len(objects)
    }

@app.post("/objects/save")
async def save_object_placement(
    session_id: str = Form(...),
    object_type: str = Form(...),
    position: str = Form(...),  # JSON string of position
    rotation: Optional[str] = Form(None),  # JSON string of rotation
    metadata: Optional[str] = Form("{}")
):
    """Save a placed AR object with position data"""
    logger.info(f"Saving object placement for session: {session_id}")
    
    try:
        import json
        position_data = json.loads(position)
        rotation_data = json.loads(rotation) if rotation else None
        meta = json.loads(metadata)
        
        # Create object data
        object_data = {
            "id": str(uuid.uuid4()),
            "type": object_type,
            "position": position_data,
            "rotation": rotation_data,
            "timestamp": datetime.now().isoformat(),
            "session_id": session_id,
            "metadata": meta
        }
        
        # Save to session directory
        session_dir = config.SESSIONS_DIR / session_id
        session_dir.mkdir(parents=True, exist_ok=True)
        
        # Save object data
        objects_file = session_dir / "objects.json"
        
        # Load existing objects if file exists
        existing_objects = []
        if objects_file.exists():
            with open(objects_file, 'r') as f:
                existing_objects = json.load(f)
        
        # Add new object
        existing_objects.append(object_data)
        
        # Save updated list
        with open(objects_file, 'w') as f:
            json.dump(existing_objects, f, indent=2)
        
        logger.info(f"Object saved: {object_data['id']}")
        
        return {
            "success": True,
            "object_id": object_data["id"],
            "total_objects": len(existing_objects)
        }
        
    except Exception as e:
        logger.error(f"Failed to save object: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/download/{capture_id}/{media_type}")
async def download_capture(capture_id: str, media_type: str):
    """Download a specific capture file"""
    # Find the file in any session directory that contains this capture_id
    for session_dir in config.SESSIONS_DIR.iterdir():
        if session_dir.is_dir():
            # Check if this session has the capture_id in any metadata file
            for metadata_file in session_dir.glob("metadata_*.json"):
                if capture_id in metadata_file.name:
                    # Found the session, now look for the media file
                    for file in session_dir.iterdir():
                        if media_type in file.name.lower():
                            return FileResponse(file)
    
    raise HTTPException(status_code=404, detail="File not found")

@app.get("/status")
async def server_status():
    """Get server status and statistics"""
    logger.info("Status endpoint accessed")
    upload_count = sum(1 for _ in config.SESSIONS_DIR.rglob("*") if _.is_file())
    
    return {
        "status": "operational",
        "sessions": len(session_manager.sessions),
        "captures": len(session_manager.captures),
        "files_stored": upload_count,
        "storage_used_mb": sum(
            f.stat().st_size for f in config.SESSIONS_DIR.rglob("*") if f.is_file()
        ) / (1024 * 1024),
        "config": {
            "forward_apis": config.FORWARD_APIS,
            "ai_processing": config.ENABLE_AI_PROCESSING,
            "storage_days": config.STORAGE_DAYS
        }
    }

@app.get("/poll")
async def poll_for_objects(session_id: Optional[str] = None):
    """Poll for new AR objects (placeholder for future implementation)"""
    # This would check for processed results ready to send back
    return {"objects": []}

# AR Session Management Endpoints
@app.get("/ar/{session_id}/objects")
async def get_ar_objects(session_id: str):
    """Get all AR objects for a session"""
    logger.info(f"Getting AR objects for session: {session_id}")
    
    # Check for objects.json file
    session_dir = config.SESSIONS_DIR / session_id
    objects_file = session_dir / "objects.json"
    
    if objects_file.exists():
        try:
            with open(objects_file, 'r') as f:
                objects = json.load(f)
            logger.info(f"Found {len(objects)} objects for session {session_id}")
            return {
                "session_id": session_id,
                "objects": objects,
                "count": len(objects)
            }
        except Exception as e:
            logger.error(f"Error reading objects file: {e}")
    
    # Return empty if no objects found
    return {
        "session_id": session_id,
        "objects": [],
        "count": 0
    }

@app.post("/ar/{session_id}/objects")
async def save_ar_object(session_id: str, request: Dict[str, Any]):
    """Save a new AR object to the session"""
    logger.info(f"Saving AR object for session: {session_id}")
    
    # Ensure session directory exists
    session_dir = config.SESSIONS_DIR / session_id
    session_dir.mkdir(parents=True, exist_ok=True)
    
    objects_file = session_dir / "objects.json"
    
    # Load existing objects or create new list
    objects = []
    if objects_file.exists():
        try:
            with open(objects_file, 'r') as f:
                objects = json.load(f)
        except:
            objects = []
    
    # Add new object
    new_object = {
        "id": request.get("id", str(uuid.uuid4())),
        "type": request.get("type", "cube"),
        "position": request.get("position", [0, 0, 0]),
        "rotation": request.get("rotation"),
        "timestamp": datetime.now().isoformat(),
        "session_id": session_id,
        "metadata": request.get("metadata", {})
    }
    
    objects.append(new_object)
    
    # Save updated objects
    try:
        with open(objects_file, 'w') as f:
            json.dump(objects, f, indent=2)
        logger.info(f"Saved object {new_object['id']} to session {session_id}")
        return {"success": True, "object": new_object}
    except Exception as e:
        logger.error(f"Failed to save object: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.delete("/ar/{session_id}/objects")
async def clear_ar_objects(session_id: str):
    """Clear all AR objects for a session"""
    logger.info(f"Clearing AR objects for session: {session_id}")
    
    session_dir = config.SESSIONS_DIR / session_id
    objects_file = session_dir / "objects.json"
    
    if objects_file.exists():
        try:
            objects_file.unlink()
            logger.info(f"Cleared all objects for session {session_id}")
            return {"success": True, "message": "All objects cleared"}
        except Exception as e:
            logger.error(f"Failed to clear objects: {e}")
            raise HTTPException(status_code=500, detail=str(e))
    
    return {"success": True, "message": "No objects to clear"}

# WebSocket support for real-time updates (future)
from fastapi import WebSocket, WebSocketDisconnect

@app.websocket("/ws/{client_id}")
async def websocket_endpoint(websocket: WebSocket, client_id: str):
    await websocket.accept()
    logger.info(f"WebSocket connected: {client_id}")
    
    try:
        while True:
            data = await websocket.receive_text()
            # Process real-time data
            await websocket.send_text(f"Echo: {data}")
    except WebSocketDisconnect:
        logger.info(f"WebSocket disconnected: {client_id}")

# Cleanup task
async def cleanup_old_files():
    """Remove files older than configured days"""
    from datetime import timedelta
    cutoff = datetime.now() - timedelta(days=config.STORAGE_DAYS)
    
    # Clean up old session directories
    for session_dir in config.SESSIONS_DIR.iterdir():
        if session_dir.is_dir():
            # Check the oldest file in the session
            oldest_time = min(
                (f.stat().st_mtime for f in session_dir.rglob("*") if f.is_file()),
                default=session_dir.stat().st_mtime
            )
            if datetime.fromtimestamp(oldest_time) < cutoff:
                import shutil
                shutil.rmtree(session_dir)
                logger.info(f"Cleaned up old session: {session_dir}")

@app.on_event("startup")
async def startup_event():
    """Initialize server on startup"""
    logger.info("AI Frame Processing Server starting...")
    
    # Load config from environment
    if os.getenv("FORWARD_APIS"):
        config.FORWARD_APIS = os.getenv("FORWARD_APIS").split(",")
    
    config.ENABLE_AI_PROCESSING = os.getenv("ENABLE_AI", "false").lower() == "true"
    
    logger.info(f"Configuration loaded: {config.__dict__}")

if __name__ == "__main__":
    # Run server
    uvicorn.run(
        app,
        host="0.0.0.0",
        port=int(os.getenv("PORT", 3001)),
        log_level="info"
    )