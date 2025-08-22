# AI Frame - Claude Context File

## Project Overview
Modular capture system with multiple interfaces:
1. **WebXR Interface** - VR/AR headset capture (Quest, etc.)
2. **Mobile Interface** - Phone-based capture app
3. **Python API Server** - Central processing hub that receives, stores, and forwards media
4. **QR Launcher** - Easy device onboarding via QR codes

All captured media flows to a local Python server that can store, process, and forward to external APIs.

## Environment Details
- **OS**: Ubuntu 22.04 (GitHub Codespaces)
- **Shell**: bash
- **Node.js**: v22.17.0
- **Python**: 3.12.1
- **Git**: 2.50.1
- **Working Directory**: `/workspaces/ai-frame`

## Available Tools
- **Runtime**: node, python3, pip, npm
- **CLI Tools**: git, curl, jq, tmux
- **Missing**: ffmpeg (needed for audio processing)

## Project Requirements (from INSTRUCTIONS.md)

### Immovable Requirements
1. Must run in documented terminal workflow (bash/tmux)
2. No GUI dependencies unless browser-served
3. Use only open APIs or documented credentials
4. Output must be human-readable and logged
5. All dependencies must be listed in setup script

### Expected Deliverables
1. Clean working environment setup
2. CLI tools and API configuration
3. Minimal walkthrough documentation
4. Core logic implementation (voice → prompt → image upload)
5. Testing and validation with mock/real data
6. Challenge/tradeoff documentation

## Commands to Run
- **Get Quest URL**: `./get-launcher-url.sh` (auto-detects Codespaces)
- **Start All Services**: `./run-services.sh` (choose option 2 for tmux)
- **View Services**: `tmux attach -t aiframe`
- **Docker Deploy**: `docker-compose up -d`
- **Individual Services**:
  - API Server: `cd server && python3 api_server.py`
  - WebXR: `npx http-server -S -C certs/cert.pem -K certs/key.pem -p 8443`
  - Mobile: `npx http-server -p 8080`

## Architecture Plan
```
┌─────────────────────────────────────────┐
│         CAPTURE INTERFACES              │
├─────────────────────────────────────────┤
│ WebXR (VR/AR)    │    Mobile (Phone)    │
│ - Video capture  │  - Camera capture    │
│ - Canvas dumps   │  - Audio recording   │
│ - Audio record   │  - Screen capture    │
│ - Text input     │  - Text input        │
└──────────┬───────┴──────────┬───────────┘
           │                  │
           ↓                  ↓
┌─────────────────────────────────────────┐
│      PYTHON API SERVER (FastAPI)        │
├─────────────────────────────────────────┤
│ - Receive multipart uploads             │
│ - Store to disk (./uploads)             │
│ - Session management                    │
│ - Forward to external APIs              │
│ - Process media (future AI)             │
│ - WebSocket support                     │
└─────────────────────────────────────────┘
           ↓                  ↓
    Local Storage      External APIs
    (./uploads)        (configurable)
```

## Implementation Status
- [x] Environment analysis
- [x] WebXR capture system design
- [x] Video/canvas capture implementation
- [x] Audio recording module  
- [x] Text input handler
- [x] AR/VR trigger interface
- [x] API gateway configuration
- [x] Media packaging and upload
- [x] Response handling
- [x] Web interface complete (`index.html`, `styles.css`)
- [x] JavaScript modules (`js/app.js`, `js/api.js`, `js/capture.js`, `js/config.js`, `js/xr-controls.js`)
- [x] HTTPS server running (port 8443)
- [x] Example API server running (port 3001)
- [x] Setup and run scripts (`setup.sh`, `run.sh`)
- [x] Meta Quest QR code integration (`qr-launcher.html`)
- [ ] Polling service (Phase 2)
- [ ] AR object renderer (Phase 2)  
- [ ] Testing framework
- [ ] Final documentation

## Technical Stack

### Frontend
- **WebXR API**: AR/VR device access
- **MediaRecorder API**: Video/audio capture
- **Canvas API**: Frame dumps
- **A-Frame**: 3D scene management

### Backend
- **FastAPI**: Python async web framework
- **Uvicorn**: ASGI server
- **Docker**: Container orchestration
- **Redis**: Session management (optional)
- **PostgreSQL**: Persistent storage (optional)

### Development
- **tmux**: Multi-pane terminal sessions
- **Docker Compose**: Service orchestration
- **GitHub Codespaces**: Cloud development

## Server Status (RUNNING)
- **tmux Session**: `aiframe` (4 panes - API, WebXR, Mobile, Monitor)
- **Python API Server**: Starting on http://localhost:3001
- **WebXR HTTPS Server**: Starting on https://localhost:8443
- **Mobile HTTP Server**: Starting on http://localhost:8080
- **Active Sessions**: `controller-1`, `opencode-0`, `server`, `aiframe`

## Access URLs
- **WebXR (VR/AR)**: https://localhost:8443
- **Mobile Interface**: http://localhost:8080/mobile.html
- **API Server**: http://localhost:3001
- **QR Launcher**: https://localhost:8443/qr-launcher.html
- **API Documentation**: http://localhost:3001/docs (FastAPI automatic docs)

For network access (Quest, phones):
- Replace `localhost` with your machine's IP address
- Make Codespaces ports public for external access

## Quest Launch Feature 🎭
**Auto-Generated Launcher URLs for GitHub Codespaces!**

### Get Your Quest Launcher URL:
```bash
./get-launcher-url.sh
```

This automatically:
- Detects your GitHub Codespaces instance
- Generates the Meta Quest launcher URL
- Saves it to `launcher-url.txt`

### Current Codespace URLs:
- **WebXR App**: `https://psychic-spork-r74rr59pp52qxr-8443.app.github.dev`
- **Quest Launcher**: `https://www.oculus.com/open_url/?url=https%3A%2F%2Fpsychic-spork-r74rr59pp52qxr-8443.app.github.dev%2F`
- **QR Generator**: `https://psychic-spork-r74rr59pp52qxr-8443.app.github.dev/qr-launcher.html`

### How to Use:
1. Run `./get-launcher-url.sh` to get your URL
2. Create QR code with the launcher URL
3. Scan with Quest's QR Scanner app
4. Select "Open in VR" → AI Frame launches!

## Notes
- Must work in Quest browser and other WebXR browsers
- Capture triggers must be accessible in immersive mode
- API endpoint must be configurable via environment/config
- All captured media should be timestamped
- Include fallbacks for non-WebXR environments
- **TODO**: Set Codespaces port 8443 to public by default for external Quest access