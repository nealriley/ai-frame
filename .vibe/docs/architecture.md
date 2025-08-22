# AI Frame Architecture Overview

## System Architecture

### High-Level Design
```
┌──────────────────────────────────────────────────────────┐
│                    Client Layer                          │
├──────────────────────────────────────────────────────────┤
│  WebXR Interface  │  Mobile Web  │  Desktop Browser      │
│  (Quest/AR)       │  (iOS/Android)│  (Chrome/Edge)        │
└──────────┬────────┴──────┬───────┴──────┬────────────────┘
           │               │              │
           └───────────────┼──────────────┘
                          │
                    HTTPS/WSS
                          │
┌──────────────────────────┴───────────────────────────────┐
│                    API Gateway                           │
├──────────────────────────────────────────────────────────┤
│  • CORS Management      • Rate Limiting                  │
│  • SSL Termination      • Request Routing                │
│  • Load Balancing       • WebSocket Upgrade              │
└──────────────────────────┬───────────────────────────────┘
                          │
┌──────────────────────────┴───────────────────────────────┐
│                 Application Layer                        │
├──────────────────────────────────────────────────────────┤
│  FastAPI Server                                          │
│  ├── Session Management                                  │
│  ├── Object Persistence                                  │
│  ├── Media Processing                                    │
│  ├── Real-time Sync (WebSocket)                         │
│  └── Authentication/Authorization                        │
└──────────────────────────┬───────────────────────────────┘
                          │
┌──────────────────────────┴───────────────────────────────┐
│                    Data Layer                            │
├──────────────────────────────────────────────────────────┤
│  File Storage        │  Session Store  │  Cache          │
│  (Local/S3)         │  (JSON/Redis)   │  (Memory/Redis) │
└──────────────────────┴────────────────┴──────────────────┘
```

## Component Architecture

### Frontend Components

#### WebXR AR Interface
```javascript
// Component Structure
ar-persistent.html
├── Session Manager
│   ├── UUID Generation
│   ├── LocalStorage Persistence
│   └── Server Synchronization
├── XR Scene Manager
│   ├── Three.js/A-Frame Scene
│   ├── WebXR Session Handler
│   └── Render Loop
├── Hit Test Controller
│   ├── Surface Detection
│   ├── Reticle Positioning
│   └── Placement Validation
├── Object Manager
│   ├── 3D Object Creation
│   ├── Position/Rotation Tracking
│   └── Anchor Management
└── Input Handler
    ├── Controller Events
    ├── Hand Tracking
    └── Gesture Recognition
```

#### JavaScript Module Architecture
```
js/
├── api.js          // API client wrapper
├── app.js          // Main application logic
├── capture.js      // Media capture utilities
├── config.js       // Configuration management
└── xr-controls.js  // WebXR control handling
```

### Backend Components

#### FastAPI Application Structure
```python
server/
├── api_server.py       # Main application
├── models/             # Data models
│   ├── session.py      # Session models
│   ├── object.py       # AR object models
│   └── media.py        # Media upload models
├── routers/            # API endpoints
│   ├── objects.py      # Object CRUD
│   ├── sessions.py     # Session management
│   └── media.py        # Media handling
├── services/           # Business logic
│   ├── storage.py      # File storage
│   ├── sync.py         # WebSocket sync
│   └── processing.py   # Media processing
└── middleware/         # Middleware
    ├── cors.py         # CORS configuration
    ├── auth.py         # Authentication
    └── logging.py      # Request logging
```

## Data Flow Architecture

### Object Creation Flow
```
1. User Input (Trigger Press)
       ↓
2. Hit Test Detection
       ↓
3. Surface Validation
       ↓
4. Object Creation (Client)
       ↓
5. Local State Update
       ↓
6. API Request (POST /objects)
       ↓
7. Server Validation
       ↓
8. Storage (JSON/Database)
       ↓
9. WebSocket Broadcast
       ↓
10. Other Clients Update
```

### Session Management Flow
```
1. Client Initialization
       ↓
2. Check LocalStorage for Session ID
       ↓
   [Exists?] → Load Session
       ↓
   [New?] → Generate UUID
       ↓
3. Server Registration
       ↓
4. Load Existing Objects
       ↓
5. Render Scene
       ↓
6. Maintain Heartbeat
```

### Media Capture Flow
```
1. Capture Trigger (Grip Button)
       ↓
2. Canvas Snapshot/Video Frame
       ↓
3. Convert to Blob
       ↓
4. Create FormData
       ↓
5. Multipart Upload
       ↓
6. Server Processing
       ↓
7. Storage & Metadata
       ↓
8. Response with URL
```

## Storage Architecture

### File System Structure
```
server/
├── sessions/                      # Session data
│   ├── {session-id}/
│   │   ├── objects.json          # AR objects
│   │   ├── metadata.json         # Session metadata
│   │   └── screenshots/          # Captured images
│   │       ├── {timestamp}.png
│   │       └── thumbnails/
├── uploads/                       # Raw uploads
│   ├── temp/                     # Temporary files
│   └── processed/                # Processed media
└── cache/                        # Application cache
```

### Data Models

#### Session Model
```json
{
  "id": "session-1755261137861",
  "created_at": "2025-01-15T12:00:00Z",
  "updated_at": "2025-01-15T12:30:00Z",
  "device_info": {
    "type": "Quest 3",
    "browser": "Oculus Browser",
    "webxr_version": "1.0"
  },
  "objects": [],
  "settings": {
    "auto_save": true,
    "sync_enabled": true
  }
}
```

#### AR Object Model
```json
{
  "id": "obj-uuid-12345",
  "type": "cube",
  "position": {
    "x": 0.5,
    "y": 1.0,
    "z": -2.0
  },
  "rotation": {
    "x": 0,
    "y": 0,
    "z": 0,
    "w": 1
  },
  "scale": {
    "x": 0.1,
    "y": 0.1,
    "z": 0.1
  },
  "color": "#FF5733",
  "metadata": {
    "created_at": "2025-01-15T12:15:00Z",
    "anchor_id": "anchor-uuid-67890",
    "surface_type": "floor"
  }
}
```

## Network Architecture

### API Endpoints
```
BASE_URL: https://api.aiframe.app

/api/v1/
├── /sessions
│   ├── POST   /create           # Create new session
│   ├── GET    /{id}            # Get session details
│   ├── PUT    /{id}            # Update session
│   └── DELETE /{id}            # Delete session
├── /objects
│   ├── POST   /                # Create object
│   ├── GET    /                # List objects
│   ├── GET    /{id}            # Get object
│   ├── PUT    /{id}            # Update object
│   └── DELETE /{id}            # Delete object
├── /media
│   ├── POST   /upload          # Upload media
│   ├── GET    /{id}            # Get media
│   └── DELETE /{id}            # Delete media
└── /sync
    └── WS     /{session_id}    # WebSocket connection
```

### WebSocket Protocol
```javascript
// Message Types
{
  "type": "object.create",
  "data": { /* object data */ }
}

{
  "type": "object.update",
  "data": { /* updated fields */ }
}

{
  "type": "object.delete",
  "data": { "id": "object-id" }
}

{
  "type": "user.join",
  "data": { "user_id": "user-123" }
}

{
  "type": "sync.request",
  "data": { "since": "timestamp" }
}
```

## Security Architecture

### Authentication Flow
```
1. Client Request
       ↓
2. Check Authorization Header
       ↓
3. Validate JWT Token
       ↓
4. Extract User/Session Info
       ↓
5. Check Permissions
       ↓
6. Process Request
       ↓
7. Audit Log
```

### Security Layers
```
┌─────────────────────────────────────┐
│         HTTPS/TLS Layer             │
├─────────────────────────────────────┤
│      Authentication Layer           │
│  • JWT Tokens                       │
│  • Session Validation               │
├─────────────────────────────────────┤
│      Authorization Layer            │
│  • Role-Based Access                │
│  • Resource Permissions             │
├─────────────────────────────────────┤
│        Validation Layer             │
│  • Input Sanitization               │
│  • Schema Validation                │
├─────────────────────────────────────┤
│         Storage Layer               │
│  • Encrypted at Rest                │
│  • Access Controls                  │
└─────────────────────────────────────┘
```

## Performance Architecture

### Caching Strategy
```
┌──────────────────────────────────────┐
│          Browser Cache               │
│  • LocalStorage (Session)            │
│  • IndexedDB (Objects)               │
│  • Service Worker Cache              │
├──────────────────────────────────────┤
│          CDN Cache                   │
│  • Static Assets                     │
│  • Media Files                       │
├──────────────────────────────────────┤
│       Application Cache              │
│  • Memory Cache (Hot Data)          │
│  • Redis (Session Data)             │
├──────────────────────────────────────┤
│        Database Cache                │
│  • Query Results                     │
│  • Computed Values                   │
└──────────────────────────────────────┘
```

### Optimization Techniques

#### Frontend Optimizations
- **LOD (Level of Detail)**: Reduce complexity based on distance
- **Frustum Culling**: Only render visible objects
- **Texture Compression**: Use KTX2/Basis formats
- **Object Pooling**: Reuse 3D objects
- **Lazy Loading**: Load objects on demand

#### Backend Optimizations
- **Connection Pooling**: Reuse database connections
- **Async I/O**: Non-blocking operations
- **Response Compression**: Gzip/Brotli
- **Query Optimization**: Indexed lookups
- **Batch Processing**: Group operations

## Scalability Architecture

### Horizontal Scaling
```
                Load Balancer
                     │
        ┌────────────┼────────────┐
        │            │            │
    Server 1     Server 2     Server 3
        │            │            │
        └────────────┼────────────┘
                     │
              Shared Storage
              (S3/NFS/Redis)
```

### Microservices Architecture (Future)
```
API Gateway
    │
    ├── Session Service
    ├── Object Service
    ├── Media Service
    ├── Sync Service
    └── Analytics Service
```

## Monitoring Architecture

### Metrics Collection
```python
# Application Metrics
- Request rate
- Response time
- Error rate
- Active sessions
- Object count
- Storage usage

# System Metrics
- CPU usage
- Memory usage
- Disk I/O
- Network throughput
- Container health
```

### Logging Strategy
```
┌─────────────────────────────────────┐
│       Application Logs              │
│  • API requests                     │
│  • WebSocket events                 │
│  • Error traces                     │
├─────────────────────────────────────┤
│        Access Logs                  │
│  • HTTP requests                    │
│  • User agents                      │
│  • Response codes                   │
├─────────────────────────────────────┤
│        Audit Logs                   │
│  • User actions                     │
│  • Data modifications               │
│  • Security events                  │
└─────────────────────────────────────┘
```

## Deployment Architecture

### Development Environment
```
Local Machine
    │
    ├── tmux Session
    │   ├── API Server (Python)
    │   ├── WebXR Server (Node)
    │   └── Mobile Server (Node)
    │
    └── File System
        ├── Source Code
        └── Local Storage
```

### Production Environment
```
Cloud Provider (AWS/GCP/Azure)
    │
    ├── Load Balancer
    │   └── Auto-scaling Group
    │       ├── EC2/VM Instances
    │       └── Container Service
    │
    ├── Storage Services
    │   ├── S3/Blob Storage
    │   └── Database Service
    │
    └── Supporting Services
        ├── CDN
        ├── Cache (Redis)
        └── Monitoring
```

## Technology Decisions

### Why WebXR?
- **Native browser support**: No app installation required
- **Cross-platform**: Works on various AR/VR devices
- **Web standards**: Future-proof technology
- **Easy updates**: Instant deployment of changes

### Why FastAPI?
- **High performance**: Built on Starlette and Pydantic
- **Type safety**: Python type hints
- **Auto documentation**: Swagger/OpenAPI generation
- **Async support**: Modern async/await patterns
- **WebSocket support**: Real-time capabilities

### Why UUID Sessions?
- **Stateless**: No server-side session storage required
- **Scalable**: Easy horizontal scaling
- **Persistent**: Can survive server restarts
- **Shareable**: Users can share sessions via URL

### Why File-Based Storage?
- **Simple**: No database setup required
- **Portable**: Easy backup and migration
- **Debuggable**: Human-readable JSON files
- **Fast**: Direct file system access
- **Suitable**: Good for prototype/small deployments

## Future Architecture Considerations

### Planned Enhancements
1. **Database Integration**: PostgreSQL for production
2. **Cloud Storage**: S3/Azure Blob for media
3. **Container Orchestration**: Kubernetes deployment
4. **Service Mesh**: Istio for microservices
5. **Event Streaming**: Kafka for real-time events
6. **ML Pipeline**: TensorFlow for object recognition

### Scaling Considerations
- **Database**: Move from files to PostgreSQL/MongoDB
- **Caching**: Add Redis for session management
- **CDN**: CloudFront/Cloudflare for global distribution
- **Queue**: RabbitMQ/SQS for async processing
- **Search**: Elasticsearch for object queries

## Architecture Principles

### Design Principles
1. **Separation of Concerns**: Clear component boundaries
2. **Single Responsibility**: Each module has one purpose
3. **Open/Closed**: Extensible without modification
4. **DRY**: Don't Repeat Yourself
5. **KISS**: Keep It Simple, Stupid

### Operational Principles
1. **Observability**: Comprehensive logging and monitoring
2. **Resilience**: Graceful failure handling
3. **Security**: Defense in depth
4. **Performance**: Optimize critical paths
5. **Maintainability**: Clear code and documentation

## References
- [WebXR Architecture](https://www.w3.org/TR/webxr/)
- [FastAPI Best Practices](https://fastapi.tiangolo.com/tutorial/best-practices/)
- [Microservices Patterns](https://microservices.io/patterns/)
- [Cloud Native Architecture](https://www.cncf.io/)
- [System Design Primer](https://github.com/donnemartin/system-design-primer)