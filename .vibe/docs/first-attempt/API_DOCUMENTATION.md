# AI Frame API Documentation

## Overview
The AI Frame API Server is a FastAPI-based service that handles AR/VR object persistence, media uploads, and session management. All data is stored as JSON files on disk for simplicity and portability.

## Base URL
- Local: `http://localhost:3001`
- HTTPS (WebXR): `https://localhost:8443`

## Core Endpoints

### AR Object Management

#### GET `/ar/{session_id}/objects`
Retrieve all AR objects for a session.

**Response:**
```json
{
  "session_id": "demo-world",
  "objects": [
    {
      "id": "uuid-here",
      "type": "cube",
      "position": [x, y, z],
      "rotation": [x, y, z],
      "timestamp": "2025-08-14T11:41:14.471864",
      "session_id": "demo-world",
      "metadata": {
        "color": 4,
        "timestamp": 1755171674419
      }
    }
  ],
  "count": 52
}
```

#### POST `/ar/{session_id}/objects`
Save a new AR object to a session.

**Request Body:**
```json
{
  "id": "optional-uuid",
  "type": "cube",
  "position": [1, 2, 3],
  "rotation": [0, 0, 0],
  "metadata": {
    "color": "red",
    "custom_field": "value"
  }
}
```

**Response:**
```json
{
  "success": true,
  "object": {
    "id": "generated-or-provided-uuid",
    "type": "cube",
    "position": [1, 2, 3],
    "rotation": [0, 0, 0],
    "timestamp": "2025-08-14T15:04:15.415073",
    "session_id": "test-session",
    "metadata": {}
  }
}
```

#### DELETE `/ar/{session_id}/objects`
Clear all objects for a session.

**Response:**
```json
{
  "success": true,
  "message": "All objects cleared"
}
```

### Media Upload

#### POST `/upload`
Upload media files (images, video, audio) with metadata.

**Request:** Multipart form data
- `image` or `video` or `audio`: File upload
- `source`: "webxr" | "mobile" | "desktop"
- `session_id`: Session identifier
- `text`: Optional text/JSON metadata

**Response:**
```json
{
  "capture_id": "uuid",
  "session_id": "session-name",
  "files": ["image.png"],
  "timestamp": "2025-08-14T10:00:00"
}
```

### Session Management

#### POST `/session/create`
Create a new capture session.

**Request:** Form data
- `device_id`: Device identifier

**Response:**
```json
{
  "session_id": "uuid",
  "device_id": "device-name",
  "created": "2025-08-14T10:00:00"
}
```

#### GET `/sessions`
List all active sessions.

**Response:**
```json
{
  "sessions": [
    {
      "session_id": "uuid",
      "device_id": "device-name",
      "created": "2025-08-14T10:00:00",
      "captures": 5
    }
  ]
}
```

### Server Status

#### GET `/status`
Get server health and statistics.

**Response:**
```json
{
  "status": "operational",
  "sessions": 3,
  "captures": 150,
  "files_stored": 452,
  "storage_used_mb": 125.4,
  "config": {
    "forward_apis": [],
    "ai_processing": false,
    "storage_days": 7
  }
}
```

## Data Storage Structure

All data is stored in the filesystem under `./server/uploads/`:

```
uploads/
├── webxr/
│   ├── demo-world/
│   │   └── objects.json       # AR objects for session
│   ├── session-uuid/
│   │   ├── objects.json       # AR objects
│   │   ├── metadata.json      # Session metadata
│   │   ├── image_001.png      # Captured images
│   │   └── text.txt          # Text/notes
│   └── ...
├── mobile/
│   └── ...
└── desktop/
    └── ...
```

### objects.json Format
```json
[
  {
    "id": "unique-object-id",
    "type": "cube|sphere|model",
    "position": [x, y, z],
    "rotation": [x, y, z],
    "scale": [x, y, z],
    "timestamp": "ISO-8601",
    "session_id": "session-name",
    "metadata": {
      "color": "color-value",
      "material": "material-type",
      "custom": "any-custom-data"
    }
  }
]
```

## WebSocket Support

#### WS `/ws/{client_id}`
Real-time bidirectional communication (future implementation).

## Error Handling

All endpoints return standard HTTP status codes:
- `200`: Success
- `404`: Resource not found
- `422`: Validation error
- `500`: Server error

Error response format:
```json
{
  "detail": "Error message here"
}
```

## CORS Configuration
The server allows all origins (*) for development. Restrict in production.

## Authentication
Currently no authentication. Add JWT tokens for production use.

## Rate Limiting
No rate limiting implemented. Add for production deployment.

## Notes
- All file operations are atomic (read full file, modify, write full file)
- JSON files are pretty-printed with 2-space indentation
- Timestamps are ISO-8601 format
- UUIDs are generated using Python's uuid4()
- Files older than 7 days are automatically cleaned up