# Session Management Documentation

## Overview
Session management in AI Frame enables persistent AR experiences where users can maintain state across browser sessions and share experiences with others. This document covers the complete session lifecycle and implementation patterns.

## Architecture

### Session Identifier Strategy
```
┌──────────────────────────────────────────┐
│          Client (Browser)                │
│  ┌────────────────────────────────────┐  │
│  │   localStorage['ar-session-id']    │  │
│  │   UUID: session-1755261137861      │  │
│  └────────────────────────────────────┘  │
└──────────────────┬───────────────────────┘
                   │
                   ↓ HTTP/WebSocket
┌──────────────────────────────────────────┐
│          Server (FastAPI)                │
│  ┌────────────────────────────────────┐  │
│  │   /sessions/{session_id}/          │  │
│  │   - metadata.json                  │  │
│  │   - objects.json                   │  │
│  │   - screenshots/                   │  │
│  └────────────────────────────────────┘  │
└──────────────────────────────────────────┘
```

## Implementation

### Client-Side Session Management

#### Session Initialization
```javascript
class SessionManager {
    constructor() {
        this.sessionId = null;
        this.sessionData = {};
        this.storageKey = 'ar-session-id';
        this.metadataKey = 'ar-session-metadata';
    }
    
    initialize() {
        // Check for existing session
        this.sessionId = localStorage.getItem(this.storageKey);
        
        if (!this.sessionId) {
            // Create new session
            this.sessionId = this.generateSessionId();
            localStorage.setItem(this.storageKey, this.sessionId);
            
            // Initialize metadata
            this.sessionData = {
                id: this.sessionId,
                created: Date.now(),
                lastAccessed: Date.now(),
                device: this.getDeviceInfo(),
                objects: []
            };
            
            this.saveMetadata();
            this.registerWithServer();
        } else {
            // Load existing session
            this.loadMetadata();
            this.syncWithServer();
        }
        
        return this.sessionId;
    }
    
    generateSessionId() {
        // Format: session-{timestamp}
        return `session-${Date.now()}`;
        
        // Alternative: UUID v4
        // return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, (c) => {
        //     const r = Math.random() * 16 | 0;
        //     const v = c === 'x' ? r : (r & 0x3 | 0x8);
        //     return v.toString(16);
        // });
    }
    
    getDeviceInfo() {
        return {
            userAgent: navigator.userAgent,
            platform: navigator.platform,
            webxr: 'xr' in navigator,
            screen: {
                width: window.screen.width,
                height: window.screen.height
            }
        };
    }
}
```

#### Session Persistence
```javascript
class PersistentSession extends SessionManager {
    saveMetadata() {
        this.sessionData.lastAccessed = Date.now();
        localStorage.setItem(this.metadataKey, JSON.stringify(this.sessionData));
    }
    
    loadMetadata() {
        const stored = localStorage.getItem(this.metadataKey);
        if (stored) {
            this.sessionData = JSON.parse(stored);
            this.sessionData.lastAccessed = Date.now();
            this.saveMetadata();
        }
    }
    
    async registerWithServer() {
        try {
            const response = await fetch('/api/sessions/create', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    id: this.sessionId,
                    device: this.sessionData.device,
                    created: this.sessionData.created
                })
            });
            
            if (response.ok) {
                const data = await response.json();
                console.log('Session registered:', data);
            }
        } catch (error) {
            console.error('Failed to register session:', error);
        }
    }
    
    async syncWithServer() {
        try {
            const response = await fetch(`/api/sessions/${this.sessionId}`);
            if (response.ok) {
                const serverData = await response.json();
                this.mergeSessionData(serverData);
            }
        } catch (error) {
            console.error('Failed to sync session:', error);
        }
    }
    
    mergeSessionData(serverData) {
        // Merge server data with local data
        this.sessionData.objects = serverData.objects || this.sessionData.objects;
        this.sessionData.settings = serverData.settings || this.sessionData.settings;
        this.saveMetadata();
    }
}
```

#### Session Lifecycle Events
```javascript
class SessionLifecycle extends PersistentSession {
    constructor() {
        super();
        this.heartbeatInterval = null;
        this.syncInterval = null;
    }
    
    start() {
        this.initialize();
        
        // Start heartbeat
        this.heartbeatInterval = setInterval(() => {
            this.sendHeartbeat();
        }, 30000); // Every 30 seconds
        
        // Start auto-sync
        this.syncInterval = setInterval(() => {
            this.syncWithServer();
        }, 60000); // Every minute
        
        // Handle page visibility
        document.addEventListener('visibilitychange', () => {
            if (document.hidden) {
                this.onBackground();
            } else {
                this.onForeground();
            }
        });
        
        // Handle page unload
        window.addEventListener('beforeunload', () => {
            this.onUnload();
        });
    }
    
    async sendHeartbeat() {
        await fetch(`/api/sessions/${this.sessionId}/heartbeat`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ timestamp: Date.now() })
        });
    }
    
    onBackground() {
        // Save state when app goes to background
        this.saveMetadata();
        this.syncWithServer();
    }
    
    onForeground() {
        // Restore state when app comes to foreground
        this.loadMetadata();
        this.syncWithServer();
    }
    
    onUnload() {
        // Final save before page closes
        this.saveMetadata();
        
        // Use sendBeacon for reliable unload data
        navigator.sendBeacon(
            `/api/sessions/${this.sessionId}/close`,
            JSON.stringify({ timestamp: Date.now() })
        );
    }
    
    stop() {
        clearInterval(this.heartbeatInterval);
        clearInterval(this.syncInterval);
    }
}
```

### Server-Side Session Management

#### FastAPI Session Models
```python
from pydantic import BaseModel, Field
from typing import Optional, List, Dict, Any
from datetime import datetime
import uuid

class DeviceInfo(BaseModel):
    user_agent: str
    platform: str
    webxr: bool
    screen: Dict[str, int]

class SessionCreate(BaseModel):
    id: Optional[str] = Field(default_factory=lambda: f"session-{int(datetime.now().timestamp() * 1000)}")
    device: DeviceInfo
    created: int = Field(default_factory=lambda: int(datetime.now().timestamp() * 1000))

class SessionData(BaseModel):
    id: str
    device: DeviceInfo
    created: datetime
    last_accessed: datetime
    objects: List[Dict[str, Any]] = []
    settings: Dict[str, Any] = {}
    metadata: Dict[str, Any] = {}

class SessionHeartbeat(BaseModel):
    timestamp: int
    status: str = "active"
```

#### Session Storage Service
```python
import json
import os
from pathlib import Path
from typing import Optional, List
from datetime import datetime, timedelta
import asyncio
import aiofiles

class SessionStorageService:
    def __init__(self, base_path: str = "./sessions"):
        self.base_path = Path(base_path)
        self.base_path.mkdir(exist_ok=True)
        self.active_sessions = {}
        self.cleanup_interval = 3600  # 1 hour
    
    async def create_session(self, session_data: SessionCreate) -> SessionData:
        """Create a new session"""
        session_id = session_data.id
        session_path = self.base_path / session_id
        session_path.mkdir(exist_ok=True)
        
        # Create session data
        session = SessionData(
            id=session_id,
            device=session_data.device,
            created=datetime.fromtimestamp(session_data.created / 1000),
            last_accessed=datetime.now(),
            objects=[],
            settings={},
            metadata={}
        )
        
        # Save to disk
        await self.save_session(session)
        
        # Cache in memory
        self.active_sessions[session_id] = session
        
        return session
    
    async def get_session(self, session_id: str) -> Optional[SessionData]:
        """Get session by ID"""
        # Check memory cache first
        if session_id in self.active_sessions:
            session = self.active_sessions[session_id]
            session.last_accessed = datetime.now()
            return session
        
        # Load from disk
        session_path = self.base_path / session_id / "metadata.json"
        if session_path.exists():
            async with aiofiles.open(session_path, 'r') as f:
                data = json.loads(await f.read())
                session = SessionData(**data)
                session.last_accessed = datetime.now()
                
                # Cache in memory
                self.active_sessions[session_id] = session
                
                return session
        
        return None
    
    async def save_session(self, session: SessionData):
        """Save session to disk"""
        session_path = self.base_path / session.id
        session_path.mkdir(exist_ok=True)
        
        metadata_path = session_path / "metadata.json"
        async with aiofiles.open(metadata_path, 'w') as f:
            await f.write(session.model_dump_json(indent=2))
    
    async def update_heartbeat(self, session_id: str, timestamp: int):
        """Update session heartbeat"""
        session = await self.get_session(session_id)
        if session:
            session.last_accessed = datetime.fromtimestamp(timestamp / 1000)
            session.metadata["last_heartbeat"] = timestamp
            await self.save_session(session)
    
    async def cleanup_inactive_sessions(self, inactive_hours: int = 24):
        """Clean up inactive sessions"""
        cutoff_time = datetime.now() - timedelta(hours=inactive_hours)
        
        for session_id in list(self.active_sessions.keys()):
            session = self.active_sessions[session_id]
            if session.last_accessed < cutoff_time:
                # Remove from memory cache
                del self.active_sessions[session_id]
                
                # Optionally archive to cold storage
                await self.archive_session(session_id)
    
    async def archive_session(self, session_id: str):
        """Archive inactive session"""
        session_path = self.base_path / session_id
        archive_path = self.base_path / "archived" / session_id
        
        if session_path.exists():
            archive_path.parent.mkdir(exist_ok=True)
            session_path.rename(archive_path)
```

#### Session API Endpoints
```python
from fastapi import FastAPI, HTTPException, BackgroundTasks
from typing import List

app = FastAPI()
session_service = SessionStorageService()

@app.post("/api/sessions/create")
async def create_session(session_data: SessionCreate):
    """Create a new AR session"""
    session = await session_service.create_session(session_data)
    return {
        "session_id": session.id,
        "created": session.created.isoformat(),
        "status": "active"
    }

@app.get("/api/sessions/{session_id}")
async def get_session(session_id: str):
    """Get session details"""
    session = await session_service.get_session(session_id)
    if not session:
        raise HTTPException(status_code=404, detail="Session not found")
    
    return session

@app.post("/api/sessions/{session_id}/heartbeat")
async def session_heartbeat(
    session_id: str,
    heartbeat: SessionHeartbeat
):
    """Update session heartbeat"""
    await session_service.update_heartbeat(session_id, heartbeat.timestamp)
    return {"status": "ok", "session_id": session_id}

@app.delete("/api/sessions/{session_id}")
async def delete_session(session_id: str):
    """Delete a session and all its data"""
    session = await session_service.get_session(session_id)
    if not session:
        raise HTTPException(status_code=404, detail="Session not found")
    
    # Remove from memory
    if session_id in session_service.active_sessions:
        del session_service.active_sessions[session_id]
    
    # Remove from disk
    session_path = session_service.base_path / session_id
    if session_path.exists():
        import shutil
        shutil.rmtree(session_path)
    
    return {"status": "deleted", "session_id": session_id}

@app.get("/api/sessions")
async def list_sessions(active_only: bool = True):
    """List all sessions"""
    if active_only:
        return {
            "sessions": list(session_service.active_sessions.keys()),
            "count": len(session_service.active_sessions)
        }
    
    # List all sessions from disk
    sessions = []
    for session_dir in session_service.base_path.iterdir():
        if session_dir.is_dir() and session_dir.name != "archived":
            sessions.append(session_dir.name)
    
    return {"sessions": sessions, "count": len(sessions)}
```

### Multi-User Session Support

#### Shared Session Implementation
```javascript
class SharedSession extends SessionLifecycle {
    constructor() {
        super();
        this.websocket = null;
        this.participants = new Map();
        this.isHost = false;
    }
    
    async createSharedSession() {
        // Create a new shareable session
        this.sessionId = this.generateSessionId();
        this.isHost = true;
        
        const response = await fetch('/api/sessions/shared/create', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                host_id: this.getUserId(),
                session_id: this.sessionId,
                settings: {
                    max_participants: 10,
                    allow_editing: true
                }
            })
        });
        
        const data = await response.json();
        this.connectWebSocket();
        
        return data.share_code;
    }
    
    async joinSharedSession(shareCode) {
        // Join an existing shared session
        const response = await fetch('/api/sessions/shared/join', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                share_code: shareCode,
                user_id: this.getUserId()
            })
        });
        
        const data = await response.json();
        this.sessionId = data.session_id;
        this.isHost = false;
        
        this.connectWebSocket();
        await this.syncWithServer();
    }
    
    connectWebSocket() {
        const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
        const wsUrl = `${protocol}//${window.location.host}/ws/sessions/${this.sessionId}`;
        
        this.websocket = new WebSocket(wsUrl);
        
        this.websocket.onopen = () => {
            this.onWebSocketOpen();
        };
        
        this.websocket.onmessage = (event) => {
            this.onWebSocketMessage(event);
        };
        
        this.websocket.onclose = () => {
            this.onWebSocketClose();
        };
    }
    
    onWebSocketOpen() {
        // Send join message
        this.sendWebSocketMessage({
            type: 'user.join',
            user_id: this.getUserId(),
            is_host: this.isHost
        });
    }
    
    onWebSocketMessage(event) {
        const message = JSON.parse(event.data);
        
        switch (message.type) {
            case 'user.joined':
                this.handleUserJoined(message.data);
                break;
            case 'user.left':
                this.handleUserLeft(message.data);
                break;
            case 'object.created':
                this.handleObjectCreated(message.data);
                break;
            case 'object.updated':
                this.handleObjectUpdated(message.data);
                break;
            case 'object.deleted':
                this.handleObjectDeleted(message.data);
                break;
            case 'sync.full':
                this.handleFullSync(message.data);
                break;
        }
    }
    
    sendWebSocketMessage(message) {
        if (this.websocket && this.websocket.readyState === WebSocket.OPEN) {
            this.websocket.send(JSON.stringify(message));
        }
    }
    
    getUserId() {
        let userId = localStorage.getItem('user-id');
        if (!userId) {
            userId = 'user-' + Math.random().toString(36).substr(2, 9);
            localStorage.setItem('user-id', userId);
        }
        return userId;
    }
}
```

### Session State Management

#### State Synchronization
```python
from typing import Dict, Set
import asyncio
from fastapi import WebSocket

class SessionStateManager:
    def __init__(self):
        self.sessions: Dict[str, SessionState] = {}
        self.connections: Dict[str, Set[WebSocket]] = {}
    
    async def add_connection(self, session_id: str, websocket: WebSocket):
        """Add WebSocket connection to session"""
        if session_id not in self.connections:
            self.connections[session_id] = set()
        
        self.connections[session_id].add(websocket)
        
        # Send current state to new connection
        if session_id in self.sessions:
            await websocket.send_json({
                "type": "sync.full",
                "data": self.sessions[session_id].to_dict()
            })
    
    async def remove_connection(self, session_id: str, websocket: WebSocket):
        """Remove WebSocket connection from session"""
        if session_id in self.connections:
            self.connections[session_id].discard(websocket)
            
            # Clean up empty sessions
            if not self.connections[session_id]:
                del self.connections[session_id]
    
    async def broadcast_to_session(
        self,
        session_id: str,
        message: dict,
        exclude: WebSocket = None
    ):
        """Broadcast message to all connections in session"""
        if session_id in self.connections:
            tasks = []
            for websocket in self.connections[session_id]:
                if websocket != exclude:
                    tasks.append(websocket.send_json(message))
            
            await asyncio.gather(*tasks, return_exceptions=True)
    
    async def update_state(
        self,
        session_id: str,
        update_type: str,
        data: dict,
        source_websocket: WebSocket = None
    ):
        """Update session state and broadcast to participants"""
        # Update internal state
        if session_id not in self.sessions:
            self.sessions[session_id] = SessionState(session_id)
        
        state = self.sessions[session_id]
        
        # Apply update based on type
        if update_type == "object.created":
            state.add_object(data)
        elif update_type == "object.updated":
            state.update_object(data["id"], data)
        elif update_type == "object.deleted":
            state.remove_object(data["id"])
        
        # Broadcast to other participants
        await self.broadcast_to_session(
            session_id,
            {"type": update_type, "data": data},
            exclude=source_websocket
        )

class SessionState:
    def __init__(self, session_id: str):
        self.session_id = session_id
        self.objects = {}
        self.participants = {}
        self.last_updated = datetime.now()
    
    def add_object(self, obj: dict):
        self.objects[obj["id"]] = obj
        self.last_updated = datetime.now()
    
    def update_object(self, obj_id: str, updates: dict):
        if obj_id in self.objects:
            self.objects[obj_id].update(updates)
            self.last_updated = datetime.now()
    
    def remove_object(self, obj_id: str):
        if obj_id in self.objects:
            del self.objects[obj_id]
            self.last_updated = datetime.now()
    
    def to_dict(self):
        return {
            "session_id": self.session_id,
            "objects": list(self.objects.values()),
            "participants": list(self.participants.values()),
            "last_updated": self.last_updated.isoformat()
        }
```

## Session Security

### Authentication and Authorization
```python
from jose import JWTError, jwt
from passlib.context import CryptContext
from datetime import datetime, timedelta

class SessionSecurity:
    def __init__(self, secret_key: str):
        self.secret_key = secret_key
        self.algorithm = "HS256"
        self.pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
    
    def create_session_token(self, session_id: str, user_id: str) -> str:
        """Create JWT token for session access"""
        expire = datetime.utcnow() + timedelta(hours=24)
        payload = {
            "session_id": session_id,
            "user_id": user_id,
            "exp": expire,
            "permissions": ["read", "write"]
        }
        
        return jwt.encode(payload, self.secret_key, algorithm=self.algorithm)
    
    def verify_session_token(self, token: str) -> dict:
        """Verify and decode session token"""
        try:
            payload = jwt.decode(
                token,
                self.secret_key,
                algorithms=[self.algorithm]
            )
            return payload
        except JWTError:
            return None
    
    def generate_share_code(self, session_id: str) -> str:
        """Generate shareable code for session"""
        import hashlib
        import base64
        
        # Create hash of session ID with timestamp
        data = f"{session_id}{datetime.now().timestamp()}"
        hash_obj = hashlib.sha256(data.encode())
        
        # Create short, URL-safe code
        share_code = base64.urlsafe_b64encode(
            hash_obj.digest()[:6]
        ).decode().rstrip('=')
        
        return share_code
```

## Session Analytics

### Tracking and Metrics
```python
class SessionAnalytics:
    def __init__(self):
        self.metrics = {}
    
    async def track_session_event(
        self,
        session_id: str,
        event_type: str,
        data: dict = None
    ):
        """Track session events for analytics"""
        if session_id not in self.metrics:
            self.metrics[session_id] = {
                "created": datetime.now(),
                "events": [],
                "statistics": {}
            }
        
        event = {
            "type": event_type,
            "timestamp": datetime.now(),
            "data": data or {}
        }
        
        self.metrics[session_id]["events"].append(event)
        
        # Update statistics
        await self.update_statistics(session_id, event_type)
    
    async def update_statistics(self, session_id: str, event_type: str):
        """Update session statistics"""
        stats = self.metrics[session_id]["statistics"]
        
        # Count events
        if "event_counts" not in stats:
            stats["event_counts"] = {}
        
        stats["event_counts"][event_type] = \
            stats["event_counts"].get(event_type, 0) + 1
        
        # Update last activity
        stats["last_activity"] = datetime.now().isoformat()
    
    async def get_session_analytics(self, session_id: str):
        """Get analytics for a session"""
        if session_id not in self.metrics:
            return None
        
        metrics = self.metrics[session_id]
        
        return {
            "session_id": session_id,
            "created": metrics["created"].isoformat(),
            "total_events": len(metrics["events"]),
            "event_counts": metrics["statistics"].get("event_counts", {}),
            "last_activity": metrics["statistics"].get("last_activity"),
            "duration": self.calculate_duration(metrics)
        }
    
    def calculate_duration(self, metrics):
        """Calculate session duration"""
        if not metrics["events"]:
            return 0
        
        first_event = metrics["events"][0]["timestamp"]
        last_event = metrics["events"][-1]["timestamp"]
        
        return (last_event - first_event).total_seconds()
```

## Best Practices

### Session Management Guidelines
1. **Use UUIDs or timestamps** for session identifiers
2. **Implement heartbeats** to track active sessions
3. **Clean up inactive sessions** regularly
4. **Use WebSockets** for real-time synchronization
5. **Cache active sessions** in memory for performance
6. **Persist to disk** for recovery after crashes
7. **Implement proper error handling** for network failures
8. **Use tokens** for secure session sharing
9. **Track analytics** for usage insights
10. **Support offline mode** with local storage

### Performance Optimization
- Cache frequently accessed sessions in memory
- Use connection pooling for database access
- Implement pagination for large object lists
- Compress session data for network transfer
- Use binary protocols for WebSocket messages
- Batch updates to reduce network overhead

### Security Considerations
- Generate cryptographically secure session IDs
- Implement session expiration
- Use HTTPS/WSS for all communications
- Validate all session operations
- Implement rate limiting
- Log security events
- Encrypt sensitive session data

## References
- [Web Storage API](https://developer.mozilla.org/en-US/docs/Web/API/Web_Storage_API)
- [WebSocket API](https://developer.mozilla.org/en-US/docs/Web/API/WebSocket)
- [JWT Authentication](https://jwt.io/introduction)
- [UUID Generation](https://www.rfc-editor.org/rfc/rfc4122)