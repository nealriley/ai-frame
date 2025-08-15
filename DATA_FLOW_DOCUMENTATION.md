# AI Frame Data Flow Documentation

## Overview
This document describes the complete data flow for the AI Frame persistent AR system, including how objects are saved, loaded, and synchronized between the web UI and API server.

## System Architecture

```
┌─────────────────────┐
│   Quest Browser     │
│  (ar-persistent)    │
└──────────┬──────────┘
           │
      HTTP/HTTPS
           │
┌──────────▼──────────┐
│   FastAPI Server    │
│   (Port 3001)       │
└──────────┬──────────┘
           │
      File System
           │
┌──────────▼──────────┐
│   JSON Storage      │
│ /server/uploads/    │
└─────────────────────┘
```

## Data Flow Scenarios

### 1. Creating New AR Objects

**Web UI (ar-persistent.html):**
```javascript
// User triggers object placement
function placeNewObject() {
    const cube = createBuffer(createCubeGeometry(colors[colorIndex]));
    cube.transform = new Float32Array(reticle.transform);
    cube.id = crypto.randomUUID(); // Unique identifier
    
    objects.push(cube);
    sessionData.placed.push(cube);
    
    saveObjectToServer(cube); // Async save to API
}

// Save to API
async function saveObjectToServer(obj) {
    const position = [
        obj.transform[12],  // X coordinate
        obj.transform[13],  // Y coordinate
        obj.transform[14]   // Z coordinate
    ];
    
    await fetch(`${API_BASE}/ar/${sessionId}/objects`, {
        method: 'POST',
        headers: {'Content-Type': 'application/json'},
        body: JSON.stringify({
            id: obj.id,
            type: 'cube',
            position: position,
            metadata: {
                color: colorIndex - 1,
                timestamp: Date.now()
            }
        })
    });
}
```

**API Server (api_server.py):**
```python
@app.post("/ar/{session_id}/objects")
async def save_ar_object(session_id: str, request: Dict):
    # Create session directory if needed
    session_dir = UPLOAD_DIR / "webxr" / session_id
    session_dir.mkdir(parents=True, exist_ok=True)
    
    # Load existing objects
    objects_file = session_dir / "objects.json"
    objects = []
    if objects_file.exists():
        with open(objects_file, 'r') as f:
            objects = json.load(f)
    
    # Add new object with metadata
    new_object = {
        "id": request.get("id", str(uuid.uuid4())),
        "type": request.get("type", "cube"),
        "position": request.get("position"),
        "rotation": request.get("rotation"),
        "timestamp": datetime.now().isoformat(),
        "session_id": session_id,
        "metadata": request.get("metadata", {})
    }
    objects.append(new_object)
    
    # Save to disk
    with open(objects_file, 'w') as f:
        json.dump(objects, f, indent=2)
    
    return {"success": True, "object": new_object}
```

**File System Result:**
```
/server/uploads/webxr/{session_id}/objects.json
[
  {
    "id": "uuid-here",
    "type": "cube",
    "position": [x, y, z],
    "rotation": null,
    "timestamp": "2025-08-14T15:00:00",
    "session_id": "session-name",
    "metadata": {
      "color": 5,
      "timestamp": 1755192000000
    }
  }
]
```

### 2. Loading Existing Objects

**Web UI Session Start:**
```javascript
// User selects "Continue Last" or "Demo World"
async function loadSavedObjects() {
    const response = await fetch(`${API_BASE}/ar/${sessionId}/objects`);
    const data = await response.json();
    sessionData.savedPositions = data.objects || [];
    
    // Objects are loaded when AR session starts
    // They're rendered in the XR frame loop
}
```

**API Server:**
```python
@app.get("/ar/{session_id}/objects")
async def get_ar_objects(session_id: str):
    session_dir = UPLOAD_DIR / "webxr" / session_id
    objects_file = session_dir / "objects.json"
    
    if objects_file.exists():
        with open(objects_file, 'r') as f:
            objects = json.load(f)
        return {
            "session_id": session_id,
            "objects": objects,
            "count": len(objects)
        }
    
    return {"session_id": session_id, "objects": [], "count": 0}
```

**Web UI Object Rendering:**
```javascript
// In XR frame loop, load saved objects
for (const objData of sessionData.savedPositions) {
    const cube = createBuffer(createCubeGeometry(colors[colorIndex]));
    
    // Restore position from saved data
    cube.transform = new Float32Array(16);
    cube.transform[12] = objData.position[0];
    cube.transform[13] = objData.position[1];
    cube.transform[14] = objData.position[2];
    
    cube.id = objData.id;  // Preserve original ID
    cube.isLoaded = true;   // Mark as loaded from storage
    
    objects.push(cube);
    sessionData.loaded.push(cube);
}
```

### 3. Session Management

**Session Types:**
- **New Session**: Generated UUID, starts with empty objects array
- **Continue Last**: Uses localStorage to retrieve last session ID
- **Demo World**: Fixed session ID "demo-world" with pre-populated objects

**Session Storage:**
```javascript
// Save session for "Continue Last" feature
localStorage.setItem('lastARSession', sessionId);

// Retrieve last session
const lastSession = localStorage.getItem('lastARSession');
```

## Data Structures

### Object Format (JSON)
```json
{
  "id": "unique-uuid",
  "type": "cube",
  "position": [x, y, z],
  "rotation": [x, y, z] | null,
  "timestamp": "ISO-8601 datetime",
  "session_id": "session-identifier",
  "metadata": {
    "color": "color-index or value",
    "timestamp": "client-timestamp-ms",
    "custom": "any-additional-data"
  }
}
```

### Session Data (Client-side)
```javascript
sessionData = {
    savedPositions: [],  // Objects loaded from API
    loaded: [],         // Rendered loaded objects
    placed: []          // Newly placed objects
}
```

## API Endpoints Summary

| Method | Endpoint | Purpose |
|--------|----------|---------|
| GET | `/ar/{session}/objects` | Load all objects for session |
| POST | `/ar/{session}/objects` | Save new object to session |
| DELETE | `/ar/{session}/objects` | Clear all objects in session |
| GET | `/status` | Server health check |
| POST | `/upload` | Upload media captures |

## Testing

Run the integration test to verify the complete flow:
```bash
./integration-test.sh
```

This tests:
1. API health
2. Object creation
3. Object retrieval
4. File persistence
5. Session clearing

## Error Handling

- **Network Failures**: Objects are still added to local array, retry save on reconnect
- **Invalid Session**: Create new session directory automatically
- **Corrupt JSON**: Return empty array, log error
- **File System Errors**: Return 500 status with error details

## Performance Considerations

- Objects are loaded/saved atomically (full file read/write)
- Suitable for sessions with <1000 objects
- For larger datasets, consider:
  - Pagination for loading
  - Incremental saves
  - Database backend (PostgreSQL/Redis)

## Security Notes

- No authentication currently implemented
- Session IDs should be treated as semi-private
- Add rate limiting for production
- Validate object data before saving
- Consider adding user authentication

## Future Enhancements

1. **WebSocket Support**: Real-time object synchronization
2. **Object Types**: Support for models, images, text
3. **Collaborative Sessions**: Multiple users in same space
4. **Object Metadata**: Attachments, links, descriptions
5. **Version History**: Undo/redo with object history