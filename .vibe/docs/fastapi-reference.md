# FastAPI Reference Documentation

## Overview
FastAPI is a modern, high-performance web framework for building APIs with Python based on standard Python type hints. This document provides comprehensive reference for implementing FastAPI features in the AI Frame backend.

## Core Features
- **Automatic API documentation** (Swagger UI, ReDoc)
- **Data validation** using Pydantic
- **Type hints** for better developer experience
- **Async/await support** for high performance
- **Dependency injection** system
- **Security and authentication** utilities

## Quick Start

### Installation
```bash
pip install "fastapi[standard]"
# Or minimal installation
pip install fastapi uvicorn
```

### Basic Application
```python
from fastapi import FastAPI

app = FastAPI(
    title="AI Frame API",
    description="Backend API for AR object persistence",
    version="1.0.0"
)

@app.get("/")
async def root():
    return {"message": "AI Frame API"}
```

### Running the Server
```bash
# Development
uvicorn main:app --reload --host 0.0.0.0 --port 3001

# Production
uvicorn main:app --workers 4 --host 0.0.0.0 --port 3001
```

## Request Handling

### Path Parameters
```python
@app.get("/sessions/{session_id}")
async def get_session(session_id: str):
    return {"session_id": session_id}

# With type validation
@app.get("/items/{item_id}")
async def get_item(item_id: int):
    return {"item_id": item_id}
```

### Query Parameters
```python
@app.get("/objects")
async def list_objects(
    skip: int = 0,
    limit: int = 10,
    session_id: str | None = None
):
    return {"skip": skip, "limit": limit, "session": session_id}
```

### Request Body with Pydantic
```python
from pydantic import BaseModel, Field
from typing import Optional
from datetime import datetime

class ARObject(BaseModel):
    id: str = Field(default_factory=lambda: str(uuid.uuid4()))
    position: dict[str, float]
    rotation: dict[str, float]
    scale: float = 1.0
    type: str
    metadata: Optional[dict] = None
    created_at: datetime = Field(default_factory=datetime.now)
    
    class Config:
        json_schema_extra = {
            "example": {
                "position": {"x": 0, "y": 1, "z": -2},
                "rotation": {"x": 0, "y": 0, "z": 0, "w": 1},
                "type": "cube"
            }
        }

@app.post("/objects")
async def create_object(obj: ARObject):
    # Automatic validation and parsing
    return obj
```

### Multiple Parameter Types
```python
@app.put("/sessions/{session_id}/objects/{object_id}")
async def update_object(
    session_id: str,              # Path parameter
    object_id: str,                # Path parameter
    obj: ARObject,                 # Request body
    urgent: bool = False,          # Query parameter
    user_agent: str = Header(None) # Header parameter
):
    return {
        "session": session_id,
        "object": object_id,
        "updated": obj,
        "urgent": urgent
    }
```

## File Handling

### File Upload
```python
from fastapi import UploadFile, File

@app.post("/upload")
async def upload_file(
    file: UploadFile = File(...),
    session_id: str = Form(...)
):
    contents = await file.read()
    
    # Save file
    file_path = f"uploads/{session_id}/{file.filename}"
    with open(file_path, "wb") as f:
        f.write(contents)
    
    return {
        "filename": file.filename,
        "size": len(contents),
        "session": session_id
    }
```

### Multiple Files
```python
@app.post("/capture/batch")
async def upload_multiple(
    files: list[UploadFile] = File(...),
    metadata: str = Form(...)
):
    results = []
    for file in files:
        content = await file.read()
        # Process each file
        results.append({
            "name": file.filename,
            "size": len(content)
        })
    return {"files": results}
```

## Response Handling

### Response Models
```python
class SessionResponse(BaseModel):
    id: str
    objects: list[ARObject]
    created_at: datetime
    updated_at: datetime

@app.get("/sessions/{session_id}", response_model=SessionResponse)
async def get_session_details(session_id: str):
    # Return will be validated against SessionResponse
    return load_session(session_id)
```

### Status Codes
```python
from fastapi import status

@app.post("/objects", status_code=status.HTTP_201_CREATED)
async def create_new_object(obj: ARObject):
    return obj

@app.delete("/objects/{id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_object(id: str):
    # No content returned for 204
    pass
```

### Custom Responses
```python
from fastapi.responses import JSONResponse, FileResponse

@app.get("/download/{file_id}")
async def download_file(file_id: str):
    file_path = f"uploads/{file_id}"
    return FileResponse(
        path=file_path,
        media_type="application/octet-stream",
        filename="download.bin"
    )

@app.get("/custom")
async def custom_response():
    return JSONResponse(
        status_code=200,
        content={"message": "custom"},
        headers={"X-Custom": "header"}
    )
```

## Error Handling

### HTTP Exceptions
```python
from fastapi import HTTPException

@app.get("/objects/{object_id}")
async def get_object(object_id: str):
    obj = find_object(object_id)
    if not obj:
        raise HTTPException(
            status_code=404,
            detail=f"Object {object_id} not found",
            headers={"X-Error": "Not Found"}
        )
    return obj
```

### Custom Exception Handlers
```python
from fastapi import Request
from fastapi.responses import JSONResponse

class ValidationError(Exception):
    def __init__(self, message: str):
        self.message = message

@app.exception_handler(ValidationError)
async def validation_exception_handler(request: Request, exc: ValidationError):
    return JSONResponse(
        status_code=400,
        content={"error": exc.message}
    )
```

## Dependency Injection

### Basic Dependencies
```python
from fastapi import Depends

async def get_db_session():
    db = DatabaseSession()
    try:
        yield db
    finally:
        db.close()

@app.get("/data")
async def get_data(db: DatabaseSession = Depends(get_db_session)):
    return db.query_all()
```

### Parameterized Dependencies
```python
def pagination_params(
    skip: int = Query(0, ge=0),
    limit: int = Query(10, le=100)
):
    return {"skip": skip, "limit": limit}

@app.get("/items")
async def list_items(
    pagination: dict = Depends(pagination_params)
):
    return get_items(pagination["skip"], pagination["limit"])
```

## Middleware and CORS

### CORS Configuration
```python
from fastapi.middleware.cors import CORSMiddleware

app.add_middleware(
    CORSMiddleware,
    allow_origins=["https://localhost:8443", "https://*.github.dev"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
    expose_headers=["X-Session-ID"]
)
```

### Custom Middleware
```python
@app.middleware("http")
async def add_process_time_header(request: Request, call_next):
    start_time = time.time()
    response = await call_next(request)
    process_time = time.time() - start_time
    response.headers["X-Process-Time"] = str(process_time)
    return response
```

## Background Tasks

```python
from fastapi import BackgroundTasks

def process_upload(file_path: str, session_id: str):
    # Long running task
    time.sleep(10)
    print(f"Processed {file_path} for session {session_id}")

@app.post("/upload-async")
async def upload_with_processing(
    file: UploadFile,
    background_tasks: BackgroundTasks
):
    file_path = save_file(file)
    background_tasks.add_task(process_upload, file_path, "session-123")
    return {"message": "Upload started"}
```

## WebSocket Support

```python
from fastapi import WebSocket

@app.websocket("/ws/{session_id}")
async def websocket_endpoint(websocket: WebSocket, session_id: str):
    await websocket.accept()
    try:
        while True:
            data = await websocket.receive_text()
            # Process AR updates
            await websocket.send_json({
                "session": session_id,
                "message": f"Received: {data}"
            })
    except WebSocketDisconnect:
        print(f"Session {session_id} disconnected")
```

## Security and Authentication

### OAuth2 with JWT
```python
from fastapi.security import OAuth2PasswordBearer, OAuth2PasswordRequestForm
from jose import JWTError, jwt
from passlib.context import CryptContext

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="token")
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

SECRET_KEY = "your-secret-key"
ALGORITHM = "HS256"

async def get_current_user(token: str = Depends(oauth2_scheme)):
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        username = payload.get("sub")
        if username is None:
            raise HTTPException(status_code=401)
        return username
    except JWTError:
        raise HTTPException(status_code=401)

@app.get("/protected")
async def protected_route(current_user: str = Depends(get_current_user)):
    return {"user": current_user}
```

## Database Integration

### SQLAlchemy Setup
```python
from sqlalchemy import create_engine
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker

SQLALCHEMY_DATABASE_URL = "sqlite:///./ar_frame.db"

engine = create_engine(SQLALCHEMY_DATABASE_URL)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
```

## Testing

### Test Client
```python
from fastapi.testclient import TestClient

client = TestClient(app)

def test_create_object():
    response = client.post(
        "/objects",
        json={
            "position": {"x": 0, "y": 0, "z": 0},
            "rotation": {"x": 0, "y": 0, "z": 0, "w": 1},
            "type": "cube"
        }
    )
    assert response.status_code == 200
    assert response.json()["type"] == "cube"
```

### Async Testing
```python
import pytest
from httpx import AsyncClient

@pytest.mark.asyncio
async def test_async_endpoint():
    async with AsyncClient(app=app, base_url="http://test") as client:
        response = await client.get("/")
        assert response.status_code == 200
```

## Performance Optimization

### Async Best Practices
```python
# Good - truly async operation
@app.get("/async-data")
async def get_async_data():
    async with aiohttp.ClientSession() as session:
        async with session.get("https://api.example.com") as response:
            return await response.json()

# Good - CPU-bound in thread pool
import asyncio
from concurrent.futures import ThreadPoolExecutor

executor = ThreadPoolExecutor(max_workers=4)

@app.get("/compute")
async def compute_intensive():
    loop = asyncio.get_event_loop()
    result = await loop.run_in_executor(executor, cpu_heavy_function)
    return {"result": result}
```

### Response Caching
```python
from functools import lru_cache

@lru_cache(maxsize=128)
def get_expensive_data(param: str):
    # Expensive computation
    return compute(param)

@app.get("/cached/{param}")
async def cached_endpoint(param: str):
    return get_expensive_data(param)
```

## Deployment Configuration

### Gunicorn with Uvicorn Workers
```python
# gunicorn_conf.py
bind = "0.0.0.0:3001"
workers = 4
worker_class = "uvicorn.workers.UvicornWorker"
worker_connections = 1000
keepalive = 5
```

### Docker Deployment
```dockerfile
FROM python:3.11-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "3001"]
```

## Common Patterns for AR/XR Applications

### Session Management
```python
import uuid
from datetime import datetime, timedelta

sessions = {}

@app.post("/sessions/create")
async def create_session():
    session_id = str(uuid.uuid4())
    sessions[session_id] = {
        "id": session_id,
        "created_at": datetime.now(),
        "objects": [],
        "last_activity": datetime.now()
    }
    return {"session_id": session_id}

@app.post("/sessions/{session_id}/heartbeat")
async def session_heartbeat(session_id: str):
    if session_id in sessions:
        sessions[session_id]["last_activity"] = datetime.now()
        return {"status": "active"}
    raise HTTPException(status_code=404)
```

### Object Synchronization
```python
from typing import Dict, List
import asyncio

# Store WebSocket connections per session
connections: Dict[str, List[WebSocket]] = {}

@app.websocket("/sync/{session_id}")
async def sync_objects(websocket: WebSocket, session_id: str):
    await websocket.accept()
    
    if session_id not in connections:
        connections[session_id] = []
    connections[session_id].append(websocket)
    
    try:
        while True:
            data = await websocket.receive_json()
            # Broadcast to all other connections in session
            for conn in connections[session_id]:
                if conn != websocket:
                    await conn.send_json(data)
    except:
        connections[session_id].remove(websocket)
```