# Immediate Actions for AI Frame Development

## 🚨 Priority 1: Critical Fixes

### 1. Fix CORS Security Issue
**File**: `/workspaces/ai-frame/api/main.py`  
**Line**: 28-35

**Replace this:**
```python
allow_origins=["*"],  # Allow all origins for development
```

**With this:**
```python
import os

# Dynamic CORS based on environment
def get_allowed_origins():
    if os.getenv("CODESPACES"):
        codespace_name = os.getenv("CODESPACE_NAME")
        domain = os.getenv("GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN", "app.github.dev")
        return [
            f"https://{codespace_name}-8443.{domain}",
            f"https://{codespace_name}-8080.{domain}",
            "http://localhost:8080",
            "http://localhost:3000"
        ]
    return ["http://localhost:8080", "http://localhost:3000"]

app.add_middleware(
    CORSMiddleware,
    allow_origins=get_allowed_origins(),
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "DELETE"],
    allow_headers=["*"],
    expose_headers=["X-Session-ID"]
)
```

### 2. Add Environment Configuration
**Create file**: `/workspaces/ai-frame/api/config.py`

```python
import os
from pathlib import Path

class Settings:
    # Environment detection
    IS_CODESPACES = os.getenv("CODESPACES") == "true"
    CODESPACE_NAME = os.getenv("CODESPACE_NAME", "")
    GITHUB_USER = os.getenv("GITHUB_USER", "")
    
    # Port configuration
    API_PORT = 3001
    WEBXR_PORT = 8443
    MOBILE_PORT = 8080
    
    # URLs
    @property
    def API_URL(self):
        if self.IS_CODESPACES:
            domain = os.getenv("GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN", "app.github.dev")
            return f"https://{self.CODESPACE_NAME}-{self.API_PORT}.{domain}"
        return f"http://localhost:{self.API_PORT}"
    
    @property
    def WEBXR_URL(self):
        if self.IS_CODESPACES:
            domain = os.getenv("GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN", "app.github.dev")
            return f"https://{self.CODESPACE_NAME}-{self.WEBXR_PORT}.{domain}"
        return f"https://localhost:{self.WEBXR_PORT}"
    
    # Storage
    DATA_DIR = Path("/workspaces/ai-frame/data")
    MAX_FILE_SIZE = 100 * 1024 * 1024  # 100MB
    
    # Logging
    LOG_LEVEL = os.getenv("LOG_LEVEL", "INFO")
    LOG_DIR = Path("/workspaces/ai-frame/logs")

settings = Settings()
```

## 🎯 Priority 2: Start Services Properly

### Run Services in tmux
```bash
#!/bin/bash
# Create this script: /workspaces/ai-frame/start-services.sh

# Kill existing session if exists
tmux kill-session -t aiframe 2>/dev/null

# Create new session
tmux new-session -d -s aiframe

# Start API server (pane 0)
tmux send-keys -t aiframe:0 "cd /workspaces/ai-frame/api && python main.py" C-m

# Split for monitoring (pane 1)
tmux split-window -h -t aiframe:0
tmux send-keys -t aiframe:0.1 "watch -n 5 'curl -s http://localhost:3001/health | jq .'" C-m

echo "Services started in tmux session 'aiframe'"
echo "Attach with: tmux attach -t aiframe"

# Make ports public for Codespaces
if [ -n "$CODESPACES" ]; then
    echo "Setting ports to public..."
    gh codespace ports visibility 3001:public
    gh codespace ports visibility 8443:public
    gh codespace ports visibility 8080:public
    
    echo ""
    echo "API URL: https://${CODESPACE_NAME}-3001.app.github.dev"
    echo "WebXR URL: https://${CODESPACE_NAME}-8443.app.github.dev"
fi
```

### Make the script executable and run:
```bash
chmod +x /workspaces/ai-frame/start-services.sh
./start-services.sh
```

## 📝 Priority 3: Add Missing Endpoints

### Add to `/workspaces/ai-frame/api/main.py`:

```python
# Health check endpoint
@app.get("/health")
async def health_check():
    return {
        "status": "healthy",
        "timestamp": datetime.now().isoformat(),
        "environment": "codespaces" if os.getenv("CODESPACES") else "local",
        "api_url": settings.API_URL
    }

# Create session endpoint
@app.post("/sessions", response_model=Session)
async def create_session(name: Optional[str] = None):
    session = Session(name=name)
    session_data = session.dict()
    
    # Save to disk
    save_session_data(session.id, session_data)
    
    return session

# Get session endpoint
@app.get("/sessions/{session_id}")
async def get_session(session_id: str):
    session_data = load_session_data(session_id)
    if not session_data:
        raise HTTPException(status_code=404, detail="Session not found")
    return session_data

# Add object to session
@app.post("/sessions/{session_id}/objects", response_model=ARObject)
async def add_object(session_id: str, obj: ARObject):
    session_data = load_session_data(session_id)
    if not session_data:
        raise HTTPException(status_code=404, detail="Session not found")
    
    # Add object to session
    if "objects" not in session_data:
        session_data["objects"] = []
    
    obj_dict = obj.dict()
    session_data["objects"].append(obj_dict)
    session_data["updated_at"] = datetime.now().isoformat()
    
    # Save updated session
    save_session_data(session_id, session_data)
    
    return obj

# Upload media endpoint
@app.post("/sessions/{session_id}/upload")
async def upload_media(
    session_id: str,
    file: UploadFile = File(...),
    media_type: str = Form(...)
):
    # Validate session exists
    session_dir = get_session_dir(session_id)
    if not session_dir.exists():
        raise HTTPException(status_code=404, detail="Session not found")
    
    # Check file size
    contents = await file.read()
    if len(contents) > settings.MAX_FILE_SIZE:
        raise HTTPException(status_code=413, detail="File too large")
    
    # Create media directory
    media_dir = session_dir / media_type
    media_dir.mkdir(exist_ok=True)
    
    # Save file with timestamp
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    filename = f"{timestamp}_{file.filename}"
    file_path = media_dir / filename
    
    with open(file_path, "wb") as f:
        f.write(contents)
    
    return {
        "session_id": session_id,
        "type": media_type,
        "filename": filename,
        "size": len(contents),
        "path": str(file_path.relative_to(DATA_DIR))
    }
```

## 🧪 Priority 4: Test Your API

### Test with curl:
```bash
# Set API URL
export API_URL="http://localhost:3001"

# If in Codespaces:
if [ -n "$CODESPACES" ]; then
    export API_URL="https://${CODESPACE_NAME}-3001.app.github.dev"
fi

# Test health endpoint
curl "$API_URL/health" | jq .

# Create a session
SESSION_ID=$(curl -X POST "$API_URL/sessions" \
  -H "Content-Type: application/json" \
  -d '{"name": "Test Session"}' | jq -r '.id')

echo "Created session: $SESSION_ID"

# Add an object
curl -X POST "$API_URL/sessions/$SESSION_ID/objects" \
  -H "Content-Type: application/json" \
  -d '{
    "type": "cube",
    "position": {"x": 0, "y": 1, "z": -2},
    "color": "#FF0000"
  }' | jq .

# Get session with objects
curl "$API_URL/sessions/$SESSION_ID" | jq .
```

## 🌐 Priority 5: Create Browser Interface

### Create `/workspaces/ai-frame/static/index.html`:
```html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>AI Frame - Browser Interface</title>
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
            max-width: 800px;
            margin: 0 auto;
            padding: 20px;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
        }
        .container {
            background: white;
            border-radius: 10px;
            padding: 30px;
            box-shadow: 0 10px 40px rgba(0,0,0,0.1);
        }
        h1 {
            color: #333;
            margin-bottom: 30px;
        }
        .session-info {
            background: #f5f5f5;
            padding: 15px;
            border-radius: 5px;
            margin-bottom: 20px;
        }
        button {
            background: #667eea;
            color: white;
            border: none;
            padding: 10px 20px;
            border-radius: 5px;
            cursor: pointer;
            margin: 5px;
        }
        button:hover {
            background: #5a67d8;
        }
        .object-list {
            margin-top: 20px;
        }
        .object-item {
            background: #f9f9f9;
            padding: 10px;
            margin: 5px 0;
            border-radius: 5px;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>AI Frame Browser Interface</h1>
        
        <div class="session-info">
            <strong>Session ID:</strong> <span id="sessionId">Not created</span><br>
            <strong>API Status:</strong> <span id="apiStatus">Checking...</span>
        </div>
        
        <div>
            <button onclick="createSession()">Create Session</button>
            <button onclick="addObject()">Add Object</button>
            <button onclick="captureScreenshot()">Take Screenshot</button>
            <button onclick="startAudioRecording()">Record Audio</button>
        </div>
        
        <div class="object-list">
            <h3>Objects in Scene</h3>
            <div id="objectList"></div>
        </div>
    </div>

    <script>
        // Dynamic API URL based on environment
        const API_URL = window.location.hostname.includes('github.dev') 
            ? `https://${window.location.hostname.split('-')[0]}-3001.app.github.dev`
            : 'http://localhost:3001';
        
        let currentSession = null;
        
        // Check API status
        async function checkAPI() {
            try {
                const response = await fetch(`${API_URL}/health`);
                const data = await response.json();
                document.getElementById('apiStatus').textContent = '✅ Connected';
                console.log('API Health:', data);
            } catch (error) {
                document.getElementById('apiStatus').textContent = '❌ Disconnected';
                console.error('API Error:', error);
            }
        }
        
        // Create new session
        async function createSession() {
            try {
                const response = await fetch(`${API_URL}/sessions`, {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ name: 'Browser Session' })
                });
                
                currentSession = await response.json();
                document.getElementById('sessionId').textContent = currentSession.id;
                console.log('Session created:', currentSession);
            } catch (error) {
                console.error('Failed to create session:', error);
            }
        }
        
        // Add object to scene
        async function addObject() {
            if (!currentSession) {
                alert('Please create a session first');
                return;
            }
            
            const object = {
                type: 'cube',
                position: {
                    x: Math.random() * 4 - 2,
                    y: Math.random() * 2,
                    z: Math.random() * 4 - 2
                },
                color: '#' + Math.floor(Math.random()*16777215).toString(16)
            };
            
            try {
                const response = await fetch(`${API_URL}/sessions/${currentSession.id}/objects`, {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify(object)
                });
                
                const savedObject = await response.json();
                console.log('Object added:', savedObject);
                updateObjectList();
            } catch (error) {
                console.error('Failed to add object:', error);
            }
        }
        
        // Update object list display
        async function updateObjectList() {
            if (!currentSession) return;
            
            try {
                const response = await fetch(`${API_URL}/sessions/${currentSession.id}`);
                const session = await response.json();
                
                const listHtml = (session.objects || []).map(obj => `
                    <div class="object-item">
                        ${obj.type} at (${obj.position.x.toFixed(2)}, ${obj.position.y.toFixed(2)}, ${obj.position.z.toFixed(2)})
                        <span style="display:inline-block;width:20px;height:20px;background:${obj.color};border-radius:3px;vertical-align:middle;margin-left:10px;"></span>
                    </div>
                `).join('');
                
                document.getElementById('objectList').innerHTML = listHtml || '<p>No objects yet</p>';
            } catch (error) {
                console.error('Failed to update object list:', error);
            }
        }
        
        // Initialize
        checkAPI();
        setInterval(checkAPI, 30000); // Check every 30 seconds
    </script>
</body>
</html>
```

## ✅ Verification Checklist

After implementing these changes:

1. [ ] API server starts without errors
2. [ ] Health endpoint returns proper status
3. [ ] CORS headers are properly configured
4. [ ] Sessions can be created and retrieved
5. [ ] Objects can be added to sessions
6. [ ] Files can be uploaded
7. [ ] Browser interface connects to API
8. [ ] Ports are publicly accessible in Codespaces

## 🚀 Next Steps

Once the above is working:
1. Implement WebXR interface for Quest 3
2. Add WebSocket support for real-time updates
3. Implement proper authentication
4. Add data persistence with database
5. Create unit and integration tests

## 📚 Reference Documentation

- Review `.vibe/docs/fastapi-reference.md` for API patterns
- Check `.vibe/docs/webxr-reference.md` for XR implementation
- See `.vibe/docs/codespaces-deployment.md` for deployment