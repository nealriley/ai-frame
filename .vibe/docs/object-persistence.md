# Object Persistence Documentation

## Overview
Object persistence in AI Frame enables virtual objects to maintain their real-world positions across AR sessions. This document covers the complete implementation of 3D object storage, anchoring, and synchronization.

## Architecture

### Persistence Stack
```
┌────────────────────────────────────────┐
│         WebXR AR Session               │
│  ┌──────────────────────────────────┐  │
│  │   3D Objects (Three.js/A-Frame)  │  │
│  │   Position, Rotation, Scale      │  │
│  └──────────────────────────────────┘  │
└────────────────┬───────────────────────┘
                 │
        WebXR Anchors API
                 │
┌────────────────┴───────────────────────┐
│         Local Storage Layer            │
│  ┌──────────────────────────────────┐  │
│  │   Browser localStorage           │  │
│  │   IndexedDB (for large data)     │  │
│  └──────────────────────────────────┘  │
└────────────────┬───────────────────────┘
                 │
            REST API / WebSocket
                 │
┌────────────────┴───────────────────────┐
│         Server Storage Layer           │
│  ┌──────────────────────────────────┐  │
│  │   File System (JSON)             │  │
│  │   Database (Future)              │  │
│  └──────────────────────────────────┘  │
└────────────────────────────────────────┘
```

## Data Models

### AR Object Schema
```typescript
interface ARObject {
    // Identification
    id: string;                    // Unique identifier (UUID)
    type: 'cube' | 'sphere' | 'model' | 'text' | 'image';
    
    // Transform
    position: {
        x: number;                 // World space X
        y: number;                 // World space Y  
        z: number;                 // World space Z
    };
    
    rotation: {
        x: number;                 // Quaternion X
        y: number;                 // Quaternion Y
        z: number;                 // Quaternion Z
        w: number;                 // Quaternion W
    };
    
    scale: {
        x: number;                 // Scale factor X
        y: number;                 // Scale factor Y
        z: number;                 // Scale factor Z
    };
    
    // Visual Properties
    color?: string;                // Hex color code
    texture?: string;              // Texture URL
    opacity?: number;              // 0-1 transparency
    
    // Metadata
    created_at: number;            // Unix timestamp
    updated_at: number;            // Unix timestamp
    created_by?: string;           // User/session ID
    
    // AR-specific
    anchor_id?: string;            // WebXR anchor reference
    surface_type?: 'floor' | 'wall' | 'ceiling' | 'table';
    
    // Custom data
    metadata?: Record<string, any>;
}
```

### Storage Format
```json
{
  "session_id": "session-1755261137861",
  "version": "1.0",
  "created": "2025-01-15T12:00:00Z",
  "objects": [
    {
      "id": "obj-550e8400-e29b-41d4-a716-446655440000",
      "type": "cube",
      "position": { "x": 0.5, "y": 1.0, "z": -2.0 },
      "rotation": { "x": 0, "y": 0, "z": 0, "w": 1 },
      "scale": { "x": 0.1, "y": 0.1, "z": 0.1 },
      "color": "#FF5733",
      "created_at": 1755261137861,
      "anchor_id": "anchor-123",
      "surface_type": "floor"
    }
  ]
}
```

## Client-Side Implementation

### Object Manager Class
```javascript
class ObjectPersistenceManager {
    constructor() {
        this.objects = new Map();
        this.anchors = new Map();
        this.session = null;
        this.storageKey = 'ar-objects';
        this.maxLocalObjects = 1000;
    }
    
    initialize(sessionId) {
        this.sessionId = sessionId;
        this.loadFromLocalStorage();
        this.syncWithServer();
    }
    
    // Create and persist new object
    async createObject(hitTestPose, type = 'cube') {
        const object = {
            id: this.generateObjectId(),
            type: type,
            position: this.extractPosition(hitTestPose),
            rotation: this.extractRotation(hitTestPose),
            scale: { x: 0.1, y: 0.1, z: 0.1 },
            color: this.generateRandomColor(),
            created_at: Date.now(),
            updated_at: Date.now(),
            created_by: this.sessionId
        };
        
        // Create anchor if available
        if (window.XRSession && hitTestPose) {
            object.anchor_id = await this.createAnchor(hitTestPose);
        }
        
        // Add to local collection
        this.objects.set(object.id, object);
        
        // Save locally
        this.saveToLocalStorage();
        
        // Sync with server
        await this.saveToServer(object);
        
        // Create 3D representation
        this.render3DObject(object);
        
        return object;
    }
    
    generateObjectId() {
        return 'obj-' + crypto.randomUUID();
    }
    
    extractPosition(pose) {
        if (!pose || !pose.transform) return { x: 0, y: 0, z: 0 };
        
        const position = pose.transform.position;
        return {
            x: position.x,
            y: position.y,
            z: position.z
        };
    }
    
    extractRotation(pose) {
        if (!pose || !pose.transform) return { x: 0, y: 0, z: 0, w: 1 };
        
        const orientation = pose.transform.orientation;
        return {
            x: orientation.x,
            y: orientation.y,
            z: orientation.z,
            w: orientation.w
        };
    }
    
    generateRandomColor() {
        const colors = [
            '#FF6B6B', '#4ECDC4', '#45B7D1', '#96CEB4',
            '#FFEAA7', '#DDA0DD', '#98D8C8', '#F7DC6F'
        ];
        return colors[Math.floor(Math.random() * colors.length)];
    }
}
```

### Local Storage Implementation
```javascript
class LocalObjectStorage extends ObjectPersistenceManager {
    saveToLocalStorage() {
        try {
            const data = {
                session_id: this.sessionId,
                timestamp: Date.now(),
                objects: Array.from(this.objects.values())
            };
            
            // Check size before saving
            const serialized = JSON.stringify(data);
            const sizeInBytes = new Blob([serialized]).size;
            
            if (sizeInBytes > 5 * 1024 * 1024) { // 5MB limit
                console.warn('Object data exceeds localStorage limit');
                this.useIndexedDB(data);
                return;
            }
            
            localStorage.setItem(this.storageKey, serialized);
            localStorage.setItem(this.storageKey + '-meta', JSON.stringify({
                count: this.objects.size,
                last_saved: Date.now(),
                size: sizeInBytes
            }));
            
        } catch (error) {
            console.error('Failed to save to localStorage:', error);
            this.handleStorageError(error);
        }
    }
    
    loadFromLocalStorage() {
        try {
            const stored = localStorage.getItem(this.storageKey);
            if (!stored) return;
            
            const data = JSON.parse(stored);
            
            // Validate data
            if (data.session_id !== this.sessionId) {
                console.warn('Session mismatch, clearing local objects');
                this.clearLocalStorage();
                return;
            }
            
            // Load objects
            data.objects.forEach(obj => {
                this.objects.set(obj.id, obj);
            });
            
            console.log(`Loaded ${this.objects.size} objects from local storage`);
            
        } catch (error) {
            console.error('Failed to load from localStorage:', error);
            this.clearLocalStorage();
        }
    }
    
    clearLocalStorage() {
        localStorage.removeItem(this.storageKey);
        localStorage.removeItem(this.storageKey + '-meta');
        this.objects.clear();
    }
}
```

### IndexedDB for Large Data
```javascript
class IndexedDBObjectStorage {
    constructor() {
        this.dbName = 'AIFrameObjects';
        this.dbVersion = 1;
        this.db = null;
    }
    
    async initDB() {
        return new Promise((resolve, reject) => {
            const request = indexedDB.open(this.dbName, this.dbVersion);
            
            request.onerror = () => reject(request.error);
            request.onsuccess = () => {
                this.db = request.result;
                resolve(this.db);
            };
            
            request.onupgradeneeded = (event) => {
                const db = event.target.result;
                
                // Create object store
                if (!db.objectStoreNames.contains('objects')) {
                    const objectStore = db.createObjectStore('objects', {
                        keyPath: 'id'
                    });
                    
                    // Create indexes
                    objectStore.createIndex('session_id', 'session_id', { unique: false });
                    objectStore.createIndex('created_at', 'created_at', { unique: false });
                    objectStore.createIndex('type', 'type', { unique: false });
                }
                
                // Create metadata store
                if (!db.objectStoreNames.contains('metadata')) {
                    db.createObjectStore('metadata', { keyPath: 'key' });
                }
            };
        });
    }
    
    async saveObjects(objects) {
        if (!this.db) await this.initDB();
        
        const transaction = this.db.transaction(['objects'], 'readwrite');
        const store = transaction.objectStore('objects');
        
        const promises = objects.map(obj => {
            return new Promise((resolve, reject) => {
                const request = store.put(obj);
                request.onsuccess = () => resolve(obj.id);
                request.onerror = () => reject(request.error);
            });
        });
        
        return Promise.all(promises);
    }
    
    async loadObjects(sessionId) {
        if (!this.db) await this.initDB();
        
        return new Promise((resolve, reject) => {
            const transaction = this.db.transaction(['objects'], 'readonly');
            const store = transaction.objectStore('objects');
            const index = store.index('session_id');
            
            const request = index.getAll(sessionId);
            request.onsuccess = () => resolve(request.result);
            request.onerror = () => reject(request.error);
        });
    }
    
    async deleteObject(objectId) {
        if (!this.db) await this.initDB();
        
        return new Promise((resolve, reject) => {
            const transaction = this.db.transaction(['objects'], 'readwrite');
            const store = transaction.objectStore('objects');
            
            const request = store.delete(objectId);
            request.onsuccess = () => resolve();
            request.onerror = () => reject(request.error);
        });
    }
    
    async clearSession(sessionId) {
        if (!this.db) await this.initDB();
        
        const objects = await this.loadObjects(sessionId);
        const promises = objects.map(obj => this.deleteObject(obj.id));
        
        return Promise.all(promises);
    }
}
```

### WebXR Anchor Management
```javascript
class AnchorManager {
    constructor() {
        this.anchors = new Map();
        this.xrSession = null;
        this.referenceSpace = null;
    }
    
    setXRSession(session, referenceSpace) {
        this.xrSession = session;
        this.referenceSpace = referenceSpace;
    }
    
    async createAnchor(pose, object) {
        if (!this.xrSession || !pose) {
            console.warn('Cannot create anchor: no XR session or pose');
            return null;
        }
        
        try {
            // Create anchor at pose
            const anchor = await this.xrSession.createAnchor(
                pose.transform,
                this.referenceSpace
            );
            
            const anchorId = 'anchor-' + Date.now();
            
            this.anchors.set(anchorId, {
                anchor: anchor,
                objectId: object.id,
                created: Date.now()
            });
            
            // Listen for anchor changes
            if (anchor.anchorSpace) {
                this.trackAnchor(anchorId, anchor.anchorSpace);
            }
            
            return anchorId;
            
        } catch (error) {
            console.error('Failed to create anchor:', error);
            return null;
        }
    }
    
    trackAnchor(anchorId, anchorSpace) {
        // Track anchor in render loop
        const trackingData = this.anchors.get(anchorId);
        if (!trackingData) return;
        
        trackingData.anchorSpace = anchorSpace;
        trackingData.isTracking = true;
    }
    
    updateAnchoredObjects(frame) {
        if (!frame || !this.referenceSpace) return;
        
        for (const [anchorId, data] of this.anchors.entries()) {
            if (!data.isTracking || !data.anchorSpace) continue;
            
            try {
                const pose = frame.getPose(
                    data.anchorSpace,
                    this.referenceSpace
                );
                
                if (pose) {
                    // Update object position from anchor
                    this.updateObjectFromAnchor(data.objectId, pose);
                } else {
                    // Anchor lost tracking
                    data.isTracking = false;
                    console.warn(`Anchor ${anchorId} lost tracking`);
                }
                
            } catch (error) {
                console.error(`Error updating anchor ${anchorId}:`, error);
            }
        }
    }
    
    updateObjectFromAnchor(objectId, pose) {
        const object = this.objects.get(objectId);
        if (!object) return;
        
        // Update object transform from anchor pose
        object.position = {
            x: pose.transform.position.x,
            y: pose.transform.position.y,
            z: pose.transform.position.z
        };
        
        object.rotation = {
            x: pose.transform.orientation.x,
            y: pose.transform.orientation.y,
            z: pose.transform.orientation.z,
            w: pose.transform.orientation.w
        };
        
        // Update 3D representation
        this.update3DObject(object);
    }
    
    deleteAnchor(anchorId) {
        const data = this.anchors.get(anchorId);
        if (data && data.anchor) {
            // Note: WebXR doesn't provide anchor.delete() yet
            // Anchor will be garbage collected when reference is removed
            this.anchors.delete(anchorId);
        }
    }
}
```

## Server-Side Implementation

### Object Storage Service
```python
from typing import List, Optional, Dict, Any
from pathlib import Path
import json
import aiofiles
from datetime import datetime

class ObjectStorageService:
    def __init__(self, base_path: str = "./sessions"):
        self.base_path = Path(base_path)
        self.base_path.mkdir(exist_ok=True)
    
    async def save_object(
        self,
        session_id: str,
        object_data: dict
    ) -> dict:
        """Save a single object to session storage"""
        session_path = self.base_path / session_id
        session_path.mkdir(exist_ok=True)
        
        objects_file = session_path / "objects.json"
        
        # Load existing objects
        objects = await self.load_objects(session_id)
        
        # Add or update object
        object_data["updated_at"] = datetime.now().timestamp() * 1000
        
        # Find and update or append
        found = False
        for i, obj in enumerate(objects):
            if obj.get("id") == object_data.get("id"):
                objects[i] = object_data
                found = True
                break
        
        if not found:
            objects.append(object_data)
        
        # Save back to file
        await self.save_objects_file(session_id, objects)
        
        return object_data
    
    async def save_objects_batch(
        self,
        session_id: str,
        objects_data: List[dict]
    ) -> List[dict]:
        """Save multiple objects at once"""
        session_path = self.base_path / session_id
        session_path.mkdir(exist_ok=True)
        
        # Update timestamps
        for obj in objects_data:
            obj["updated_at"] = datetime.now().timestamp() * 1000
        
        await self.save_objects_file(session_id, objects_data)
        
        return objects_data
    
    async def load_objects(self, session_id: str) -> List[dict]:
        """Load all objects for a session"""
        objects_file = self.base_path / session_id / "objects.json"
        
        if not objects_file.exists():
            return []
        
        try:
            async with aiofiles.open(objects_file, 'r') as f:
                content = await f.read()
                data = json.loads(content)
                
                # Handle both array and object formats
                if isinstance(data, list):
                    return data
                elif isinstance(data, dict) and "objects" in data:
                    return data["objects"]
                else:
                    return []
                    
        except Exception as e:
            print(f"Error loading objects: {e}")
            return []
    
    async def save_objects_file(
        self,
        session_id: str,
        objects: List[dict]
    ):
        """Save objects to JSON file"""
        objects_file = self.base_path / session_id / "objects.json"
        
        data = {
            "session_id": session_id,
            "version": "1.0",
            "updated": datetime.now().isoformat(),
            "count": len(objects),
            "objects": objects
        }
        
        async with aiofiles.open(objects_file, 'w') as f:
            await f.write(json.dumps(data, indent=2))
    
    async def delete_object(
        self,
        session_id: str,
        object_id: str
    ) -> bool:
        """Delete a single object"""
        objects = await self.load_objects(session_id)
        
        # Filter out the object
        filtered = [obj for obj in objects if obj.get("id") != object_id]
        
        if len(filtered) < len(objects):
            await self.save_objects_file(session_id, filtered)
            return True
        
        return False
    
    async def clear_session_objects(self, session_id: str) -> int:
        """Clear all objects for a session"""
        objects = await self.load_objects(session_id)
        count = len(objects)
        
        await self.save_objects_file(session_id, [])
        
        return count
    
    async def get_object_stats(self, session_id: str) -> dict:
        """Get statistics about session objects"""
        objects = await self.load_objects(session_id)
        
        if not objects:
            return {
                "count": 0,
                "types": {},
                "size_bytes": 0
            }
        
        # Calculate statistics
        types = {}
        for obj in objects:
            obj_type = obj.get("type", "unknown")
            types[obj_type] = types.get(obj_type, 0) + 1
        
        # Calculate storage size
        json_str = json.dumps(objects)
        size_bytes = len(json_str.encode('utf-8'))
        
        return {
            "count": len(objects),
            "types": types,
            "size_bytes": size_bytes,
            "oldest": min((obj.get("created_at", 0) for obj in objects), default=0),
            "newest": max((obj.get("created_at", 0) for obj in objects), default=0)
        }
```

### Object API Endpoints
```python
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from typing import List, Optional

app = FastAPI()
storage_service = ObjectStorageService()

class ARObjectCreate(BaseModel):
    id: Optional[str] = None
    type: str
    position: dict
    rotation: dict
    scale: dict
    color: Optional[str] = None
    metadata: Optional[dict] = None

class ARObjectUpdate(BaseModel):
    position: Optional[dict] = None
    rotation: Optional[dict] = None
    scale: Optional[dict] = None
    color: Optional[str] = None
    metadata: Optional[dict] = None

@app.post("/api/objects/save")
async def save_object(
    session_id: str,
    object_data: ARObjectCreate
):
    """Save or update an AR object"""
    if not object_data.id:
        import uuid
        object_data.id = f"obj-{uuid.uuid4()}"
    
    obj_dict = object_data.model_dump()
    obj_dict["created_at"] = datetime.now().timestamp() * 1000
    
    saved = await storage_service.save_object(session_id, obj_dict)
    
    return {
        "status": "saved",
        "object": saved
    }

@app.post("/api/objects/batch")
async def save_objects_batch(
    session_id: str,
    objects: List[ARObjectCreate]
):
    """Save multiple objects at once"""
    objects_data = []
    
    for obj in objects:
        obj_dict = obj.model_dump()
        if not obj_dict.get("id"):
            import uuid
            obj_dict["id"] = f"obj-{uuid.uuid4()}"
        obj_dict["created_at"] = datetime.now().timestamp() * 1000
        objects_data.append(obj_dict)
    
    saved = await storage_service.save_objects_batch(session_id, objects_data)
    
    return {
        "status": "saved",
        "count": len(saved),
        "objects": saved
    }

@app.get("/api/objects/{session_id}")
async def get_objects(
    session_id: str,
    type_filter: Optional[str] = None,
    limit: int = 1000
):
    """Get all objects for a session"""
    objects = await storage_service.load_objects(session_id)
    
    # Apply filters
    if type_filter:
        objects = [obj for obj in objects if obj.get("type") == type_filter]
    
    # Apply limit
    objects = objects[:limit]
    
    return {
        "session_id": session_id,
        "count": len(objects),
        "objects": objects
    }

@app.patch("/api/objects/{session_id}/{object_id}")
async def update_object(
    session_id: str,
    object_id: str,
    updates: ARObjectUpdate
):
    """Update specific fields of an object"""
    objects = await storage_service.load_objects(session_id)
    
    # Find object
    object_found = None
    for obj in objects:
        if obj.get("id") == object_id:
            object_found = obj
            break
    
    if not object_found:
        raise HTTPException(status_code=404, detail="Object not found")
    
    # Apply updates
    update_dict = updates.model_dump(exclude_unset=True)
    object_found.update(update_dict)
    object_found["updated_at"] = datetime.now().timestamp() * 1000
    
    # Save back
    await storage_service.save_objects_file(session_id, objects)
    
    return {
        "status": "updated",
        "object": object_found
    }

@app.delete("/api/objects/{session_id}/{object_id}")
async def delete_object(
    session_id: str,
    object_id: str
):
    """Delete an object"""
    deleted = await storage_service.delete_object(session_id, object_id)
    
    if not deleted:
        raise HTTPException(status_code=404, detail="Object not found")
    
    return {
        "status": "deleted",
        "object_id": object_id
    }

@app.delete("/api/objects/{session_id}")
async def clear_objects(session_id: str):
    """Clear all objects for a session"""
    count = await storage_service.clear_session_objects(session_id)
    
    return {
        "status": "cleared",
        "count": count
    }

@app.get("/api/objects/{session_id}/stats")
async def get_object_stats(session_id: str):
    """Get statistics about session objects"""
    stats = await storage_service.get_object_stats(session_id)
    return stats
```

## Synchronization

### Real-time Object Sync
```javascript
class ObjectSyncManager {
    constructor(websocketUrl) {
        this.ws = null;
        this.wsUrl = websocketUrl;
        this.syncQueue = [];
        this.isConnected = false;
        this.reconnectAttempts = 0;
        this.maxReconnectAttempts = 5;
    }
    
    connect() {
        this.ws = new WebSocket(this.wsUrl);
        
        this.ws.onopen = () => {
            this.isConnected = true;
            this.reconnectAttempts = 0;
            console.log('WebSocket connected for object sync');
            
            // Flush sync queue
            this.flushSyncQueue();
        };
        
        this.ws.onmessage = (event) => {
            this.handleSyncMessage(event.data);
        };
        
        this.ws.onclose = () => {
            this.isConnected = false;
            this.attemptReconnect();
        };
        
        this.ws.onerror = (error) => {
            console.error('WebSocket error:', error);
        };
    }
    
    handleSyncMessage(data) {
        const message = JSON.parse(data);
        
        switch (message.type) {
            case 'object.created':
                this.onRemoteObjectCreated(message.data);
                break;
                
            case 'object.updated':
                this.onRemoteObjectUpdated(message.data);
                break;
                
            case 'object.deleted':
                this.onRemoteObjectDeleted(message.data);
                break;
                
            case 'sync.full':
                this.onFullSync(message.data);
                break;
                
            case 'sync.conflict':
                this.resolveConflict(message.data);
                break;
        }
    }
    
    syncObject(object, action = 'update') {
        const message = {
            type: `object.${action}`,
            data: object,
            timestamp: Date.now(),
            session_id: this.sessionId
        };
        
        if (this.isConnected) {
            this.ws.send(JSON.stringify(message));
        } else {
            // Queue for later
            this.syncQueue.push(message);
        }
    }
    
    flushSyncQueue() {
        while (this.syncQueue.length > 0 && this.isConnected) {
            const message = this.syncQueue.shift();
            this.ws.send(JSON.stringify(message));
        }
    }
    
    onRemoteObjectCreated(objectData) {
        // Check if object already exists locally
        if (!this.objects.has(objectData.id)) {
            // Add to local collection
            this.objects.set(objectData.id, objectData);
            
            // Render in scene
            this.render3DObject(objectData);
            
            // Save to local storage
            this.saveToLocalStorage();
        }
    }
    
    onRemoteObjectUpdated(objectData) {
        const localObject = this.objects.get(objectData.id);
        
        if (localObject) {
            // Check timestamps for conflict
            if (localObject.updated_at > objectData.updated_at) {
                // Local is newer, send our version
                this.syncObject(localObject, 'update');
            } else {
                // Remote is newer, update local
                this.objects.set(objectData.id, objectData);
                this.update3DObject(objectData);
                this.saveToLocalStorage();
            }
        } else {
            // Object doesn't exist locally, create it
            this.onRemoteObjectCreated(objectData);
        }
    }
    
    onRemoteObjectDeleted(data) {
        const objectId = data.id || data.object_id;
        
        if (this.objects.has(objectId)) {
            // Remove from local collection
            this.objects.delete(objectId);
            
            // Remove from scene
            this.remove3DObject(objectId);
            
            // Update local storage
            this.saveToLocalStorage();
        }
    }
    
    resolveConflict(conflictData) {
        console.warn('Sync conflict detected:', conflictData);
        
        // Simple last-write-wins strategy
        const localObject = this.objects.get(conflictData.object_id);
        const remoteObject = conflictData.remote;
        
        if (localObject.updated_at > remoteObject.updated_at) {
            // Keep local version
            this.syncObject(localObject, 'update');
        } else {
            // Accept remote version
            this.objects.set(remoteObject.id, remoteObject);
            this.update3DObject(remoteObject);
        }
    }
    
    attemptReconnect() {
        if (this.reconnectAttempts < this.maxReconnectAttempts) {
            this.reconnectAttempts++;
            
            setTimeout(() => {
                console.log(`Reconnection attempt ${this.reconnectAttempts}`);
                this.connect();
            }, Math.min(1000 * Math.pow(2, this.reconnectAttempts), 30000));
        }
    }
}
```

## Optimization Strategies

### Object Culling and LOD
```javascript
class OptimizedObjectRenderer {
    constructor() {
        this.visibleDistance = 50; // meters
        this.lodDistances = {
            high: 10,
            medium: 25,
            low: 50
        };
        this.maxVisibleObjects = 100;
    }
    
    updateVisibleObjects(cameraPosition) {
        const visibleObjects = [];
        const distances = new Map();
        
        // Calculate distances
        for (const [id, object] of this.objects) {
            const distance = this.calculateDistance(
                cameraPosition,
                object.position
            );
            
            if (distance <= this.visibleDistance) {
                distances.set(id, distance);
                visibleObjects.push({ id, object, distance });
            }
        }
        
        // Sort by distance
        visibleObjects.sort((a, b) => a.distance - b.distance);
        
        // Limit visible objects
        const toRender = visibleObjects.slice(0, this.maxVisibleObjects);
        
        // Update LOD and visibility
        toRender.forEach(({ id, object, distance }) => {
            const lod = this.calculateLOD(distance);
            this.updateObjectLOD(id, lod);
            this.setObjectVisible(id, true);
        });
        
        // Hide objects beyond limit
        visibleObjects.slice(this.maxVisibleObjects).forEach(({ id }) => {
            this.setObjectVisible(id, false);
        });
    }
    
    calculateLOD(distance) {
        if (distance <= this.lodDistances.high) return 'high';
        if (distance <= this.lodDistances.medium) return 'medium';
        return 'low';
    }
    
    calculateDistance(pos1, pos2) {
        const dx = pos1.x - pos2.x;
        const dy = pos1.y - pos2.y;
        const dz = pos1.z - pos2.z;
        return Math.sqrt(dx * dx + dy * dy + dz * dz);
    }
}
```

### Batch Operations
```javascript
class BatchObjectOperations {
    constructor() {
        this.batchSize = 50;
        this.batchTimeout = 100; // ms
        this.pendingOperations = [];
        this.batchTimer = null;
    }
    
    addOperation(operation) {
        this.pendingOperations.push(operation);
        
        if (this.pendingOperations.length >= this.batchSize) {
            this.executeBatch();
        } else {
            this.scheduleBatch();
        }
    }
    
    scheduleBatch() {
        if (this.batchTimer) return;
        
        this.batchTimer = setTimeout(() => {
            this.executeBatch();
        }, this.batchTimeout);
    }
    
    async executeBatch() {
        if (this.batchTimer) {
            clearTimeout(this.batchTimer);
            this.batchTimer = null;
        }
        
        if (this.pendingOperations.length === 0) return;
        
        const operations = this.pendingOperations.splice(0, this.batchSize);
        
        // Group by operation type
        const grouped = {
            create: [],
            update: [],
            delete: []
        };
        
        operations.forEach(op => {
            grouped[op.type].push(op.data);
        });
        
        // Execute batch operations
        const promises = [];
        
        if (grouped.create.length > 0) {
            promises.push(this.batchCreate(grouped.create));
        }
        
        if (grouped.update.length > 0) {
            promises.push(this.batchUpdate(grouped.update));
        }
        
        if (grouped.delete.length > 0) {
            promises.push(this.batchDelete(grouped.delete));
        }
        
        await Promise.all(promises);
        
        // Process remaining operations
        if (this.pendingOperations.length > 0) {
            this.scheduleBatch();
        }
    }
    
    async batchCreate(objects) {
        const response = await fetch('/api/objects/batch', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                session_id: this.sessionId,
                objects: objects
            })
        });
        
        return response.json();
    }
}
```

## Best Practices

### Object Management Guidelines
1. **Use UUIDs** for object identifiers
2. **Store minimal data** - only essential properties
3. **Implement LOD** for performance
4. **Batch operations** when possible
5. **Use compression** for large object datasets
6. **Implement cleanup** for old objects
7. **Handle anchor loss** gracefully
8. **Validate transforms** before saving
9. **Use versioning** for object schemas
10. **Cache frequently accessed objects**

### Performance Considerations
- Limit visible objects based on device capability
- Use object pooling for common types
- Implement frustum culling
- Compress textures and models
- Use binary formats for large data
- Defer non-critical updates

### Data Integrity
- Validate object data on save
- Implement transaction-like operations
- Use checksums for critical data
- Handle network failures gracefully
- Implement conflict resolution
- Regular backups of object data

## References
- [WebXR Anchors Module](https://immersive-web.github.io/anchors/)
- [IndexedDB API](https://developer.mozilla.org/en-US/docs/Web/API/IndexedDB_API)
- [Three.js Object3D](https://threejs.org/docs/#api/en/core/Object3D)
- [A-Frame Entity Component System](https://aframe.io/docs/)