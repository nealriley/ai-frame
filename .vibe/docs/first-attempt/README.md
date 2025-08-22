# AI Frame - Persistent AR World Platform

A WebXR-based augmented reality system that creates persistent virtual objects anchored to real-world surfaces. Objects remain in place across sessions, creating a true persistent AR experience.

## 🎯 Quick Access - Persistent AR World

### Main URL:
```
https://psychic-spork-r74rr59pp52qxr-8443.app.github.dev/ar-persistent.html
```

## 📱 Step-by-Step Instructions

### First Time Setup:

1. **Open Quest Browser**
   - Put on your Quest 3 headset
   - Open the browser app
   - Navigate to the URL above

2. **Choose Your Session:**
   - **🆕 New Session** - Start fresh with empty space
   - **📂 Continue Last Session** - Load your previously placed objects
   - **🎮 Demo World** - Try a pre-configured scene with sample objects

3. **Start AR:**
   - Click the **"Start AR"** button
   - Grant permissions if prompted
   - Wait for AR mode to initialize

4. **Using the AR Interface:**
   - **Look at a surface** (floor/table) - Green ring appears showing valid placement
   - **Pull Trigger** - Place a new colored cube at the green ring location
   - **Squeeze/Grip** - Save entire scene & take screenshot
   - Objects automatically save to the server as you place them

5. **Returning Later:**
   - Go to same URL
   - Choose **"Continue Last Session"**
   - Your objects will reload at the exact same positions!

### 💡 Important Features:
- **Automatic Saving** - Objects save to server instantly when placed
- **Session Memory** - Each session has unique ID stored locally
- **Clear Function** - "Clear All Data" button resets everything
- **Live Stats** - Info panel shows loaded vs newly placed objects
- **Color Variety** - Each cube uses different colors for visual distinction

## 🔧 How It Works

### Persistence System:
1. **Object Placement** - When you place a cube, its position is captured in 3D space
2. **Server Storage** - Position data saves to `/server/uploads/webxr/{session_id}/`
3. **Session Tracking** - Browser remembers your session ID in localStorage
4. **Reload on Return** - API fetches saved positions and recreates your AR world

### Data Structure:
- Each object stores: position (x,y,z), color, timestamp, session ID
- Objects remain anchored to real-world coordinates
- Multiple sessions can be maintained separately

## 🌐 Available AR Experiences

### Primary Experience:
- **`/ar-persistent.html`** - Full persistent AR world with save/load

### Additional Experiences:
- **`/ar-objects.html`** - Basic AR with colored cube placement
- **`/simple-ar.html`** - Minimal AR test interface
- **`/passthrough.html`** - Quest 3 passthrough test

## 🚀 Running the Services

### Quick Start:
```bash
# Start all services
./start.sh

# Or manually start services in tmux
tmux attach -t server
```

### Service URLs:
- **API Server**: Port 3001 - Handles object storage
- **WebXR HTTPS**: Port 8443 - Serves AR experiences
- **Portal**: Port 8080 - Web management interface

### For GitHub Codespaces:
1. Services auto-detect Codespaces environment
2. URLs automatically use public Codespaces domains
3. Make sure ports are set to **PUBLIC** for external Quest access

## 📊 API Endpoints

### Object Management:
- `GET /objects/{session_id}` - Retrieve saved object positions
- `POST /objects/save` - Save new object placement
- `POST /upload` - General media upload (screenshots, etc.)

### Session Management:
- `POST /session/create` - Create new AR session
- `GET /sessions` - List all sessions
- `DELETE /sessions/{id}` - Delete session and objects

## 🎮 Controls Reference

### Quest 3 Controls:
- **Trigger** (Index finger) - Place object at reticle
- **Grip** (Middle finger) - Save scene/screenshot
- **A Button** - Change object color (in some versions)
- **B Button** - Undo last placement (in some versions)

### Visual Indicators:
- **Green Ring** - Valid surface detected for placement
- **Colored Cubes** - Your placed objects
- **Info Panel** - Shows session stats and controls

## 🔍 Troubleshooting

### "WebXR Not Supported"
- Ensure using Quest browser (not desktop)
- Check HTTPS connection (required for WebXR)
- Grant all requested permissions

### Objects Not Saving/Loading
- Check API server is running (port 3001)
- Verify session ID is being created
- Look for errors in browser console

### Can't See Green Reticle
- Point controller at flat surface (floor/table)
- Move closer to surface
- Ensure good lighting for tracking

### Session Not Persisting
- Don't use private/incognito mode
- Allow localStorage/cookies
- Check "Continue Last Session" option

## 🛠️ Technical Details

### Tech Stack:
- **WebXR API** - AR/VR device access
- **WebGL** - 3D rendering without frameworks
- **FastAPI** - Python backend for storage
- **localStorage** - Client session persistence

### File Structure:
```
/workspaces/ai-frame/
├── ar-persistent.html    # Main persistent AR experience
├── server/
│   ├── api_server.py    # FastAPI backend
│   └── uploads/         # Stored object data
└── config/
    └── config.json      # API configuration
```

## 📝 Future Enhancements

- [ ] Different object shapes (spheres, pyramids)
- [ ] Object deletion by pointing
- [ ] Multi-user shared sessions
- [ ] Object properties (size, rotation)
- [ ] Export/import world data
- [ ] Voice commands for placement

## 🎯 The Vision

This creates a true "persistent AR" experience where virtual objects become permanent fixtures in your physical space. Place virtual markers, notes, or decorations that remain exactly where you left them - turning your room into a canvas for digital creativity that persists across time.

---

**Made for Meta Quest 3** - Optimized for the best AR passthrough experience

**GitHub Codespaces Ready** - Instant cloud development environment