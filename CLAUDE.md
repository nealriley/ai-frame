# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview
AI Frame is a persistent AR world platform that creates WebXR-based augmented reality experiences where virtual objects remain anchored to real-world surfaces across sessions.

**Core Components:**
1. **WebXR AR Interface** (`ar-persistent.html`) - Main AR experience for Quest 3 and other AR devices
2. **Python API Server** (`server/api_server.py`) - FastAPI backend handling object storage and session management
3. **Service Orchestration** - Multiple deployment options via Docker or tmux

## Commands

### Development Workflow
```bash
# Start all services (choose option 2 for tmux development)
./first-attempt/run-services.sh

# View running services
tmux attach -t aiframe

# Stop all services
tmux kill-session -t aiframe

# Get Quest launcher URL (for GitHub Codespaces)
./first-attempt/get-launcher-url.sh
```

### Service Management
```bash
# Start individual services
cd first-attempt/server && python3 api_server.py  # API on port 3001
npx http-server -S -C first-attempt/certs/cert.pem -K first-attempt/certs/key.pem -p 8443  # WebXR HTTPS
npx http-server -p 8080  # Mobile interface

# Docker deployment
cd first-attempt && docker-compose up -d
docker-compose logs -f
docker-compose down
```

### Testing
```bash
# Integration test
./first-attempt/integration-test.sh

# Test image capture
./first-attempt/test-image-capture.sh

# Monitor logs
./first-attempt/monitor-logs.sh
```

## Architecture

### Data Flow
```
Quest 3 / AR Device → WebXR Interface → FastAPI Server → Storage/Processing
                          ↓                    ↓
                    JavaScript APIs      Session Management
                    (WebXR, WebGL)         (UUID-based)
```

### Object Persistence System
- **Session Management**: Each AR session gets a unique UUID stored in browser localStorage
- **Object Storage**: 3D positions saved to `/server/uploads/webxr/{session_id}/objects.json`
- **Coordinate System**: Objects maintain real-world anchored positions using WebXR hit-test API
- **Auto-save**: Objects save immediately upon placement without manual intervention

### Key Files
- `first-attempt/ar-persistent.html` - Main AR experience with object persistence
- `first-attempt/server/api_server.py` - FastAPI backend with session/object management
- `first-attempt/run-services.sh` - Service orchestration script
- `first-attempt/docker-compose.yml` - Container configuration

## Environment Configuration

### GitHub Codespaces (Recommended Deployment)

#### Quick Start
```bash
# 1. Start all services (choose option 2 for tmux)
cd /workspaces/ai-frame/first-attempt
./run-services.sh

# 2. Set ports to PUBLIC for Quest access
gh codespace ports visibility 8443:public
gh codespace ports visibility 3001:public
gh codespace ports visibility 8080:public

# 3. Get Quest launcher URL
./get-launcher-url.sh
```

#### Environment Variables
Codespaces provides these environment variables automatically:
```bash
CODESPACES=true                           # Indicates Codespaces environment
CODESPACE_NAME=<unique-name>             # e.g., "psychic-spork-r74rr59pp52qxr"
GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN=app.github.dev
GITHUB_USER=<username>                    # Your GitHub username
GITHUB_TOKEN=<token>                      # Auth token for API access
```

#### URL Structure
Services are accessible at:
```
https://${CODESPACE_NAME}-${PORT}.${GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN}
```

Example:
- WebXR: `https://psychic-spork-r74rr59pp52qxr-8443.app.github.dev`
- API: `https://psychic-spork-r74rr59pp52qxr-3001.app.github.dev`

#### Command-Line Tools
```bash
# Port management
gh codespace ports                        # List all forwarded ports
gh codespace ports forward 3001:3001     # Forward specific port
gh codespace ports visibility 8443:public # Set port visibility

# Service monitoring
tmux ls                                   # List tmux sessions
tmux attach -t aiframe                   # Attach to service session
tmux kill-session -t aiframe             # Stop all services

# Debugging
curl http://localhost:3001/status        # Check API status
lsof -i :8443                            # Check port usage
netstat -tlnp | grep 3001                # Network connections
```

#### Optimal Configuration
- **tmux deployment** (option 2) is recommended over Docker for Codespaces
- Provides better resource usage and log visibility
- Services persist across browser refreshes
- Easy individual service restart

### Local Development
- Uses machine's local IP for network access
- Self-signed certificates generated automatically
- Requires HTTPS for WebXR (port 8443)

## API Endpoints

### Object Management
- `POST /objects/save` - Save new AR object placement
- `GET /objects/{session_id}` - Retrieve saved objects for session
- `DELETE /sessions/{session_id}` - Clear session and all objects

### Media Upload
- `POST /upload` - General multipart upload endpoint
- `POST /capture/screenshot` - Save AR scene screenshot
- `GET /sessions` - List all active sessions

## Quest 3 Controls
- **Trigger** - Place object at green reticle
- **Grip** - Save scene and capture screenshot
- **Green Ring** - Valid surface detected for placement

## Project State
Working directory structure exists in `/workspaces/ai-frame/first-attempt/` containing the complete implementation. The root `/workspaces/ai-frame/` appears to be a fresh directory for potential refactoring or new implementation.

## Important Notes
- WebXR requires HTTPS with valid certificates
- Quest browser required for AR features (not desktop)
- Objects persist in browser localStorage and server storage
- Multiple concurrent sessions supported with unique IDs
- Services can run via Docker Compose or tmux sessions

## Documentation Guidelines for Coding Agents

### Documentation Context Location
**IMPORTANT**: When researching or adding technical documentation:
1. **Check First**: Always check `.vibe/docs/` for existing documentation before web searches
2. **Primary References**: 
   - `.vibe/docs/webxr-reference.md` - WebXR API patterns and implementation
   - `.vibe/docs/fastapi-reference.md` - Backend API development patterns
   - `.vibe/docs/codespaces-reference.md` - Development environment configuration
   - `.vibe/docs/codespaces-deployment.md` - Optimal Codespaces deployment guide
   - `.vibe/docs/README.md` - Documentation index and quick links

### When to Create Documentation
Create new documentation in `.vibe/docs/` when:
- Implementing new technology not covered in existing docs
- Adding complex features requiring reference material
- Discovering patterns through research that should be preserved
- Building reusable components needing usage guides

### Documentation Structure
```
.vibe/docs/
├── README.md                 # Index and overview
├── webxr-reference.md       # WebXR implementation guide
├── fastapi-reference.md    # Backend API patterns
├── codespaces-reference.md # Environment configuration
└── [new-topic].md          # Additional topic-specific docs
```

### How to Document Research
When researching new topics:
1. **Web Search**: Use authoritative sources (official docs, GitHub repos)
2. **Extract Patterns**: Focus on implementation patterns, not just theory
3. **Code Examples**: Include working code snippets
4. **Organize Logically**: Group by feature or use case
5. **Link Sources**: Always reference original documentation

### Using Documentation in Development
When implementing features:
1. **Reference Patterns**: Use documented patterns from `.vibe/docs/`
2. **Maintain Consistency**: Follow established code patterns
3. **Update If Needed**: Add new patterns discovered during implementation
4. **Test Examples**: Ensure documented code examples work

### Key Implementation References

#### WebXR Development
- Session initialization: See "Session Initialization" in webxr-reference.md
- Hit testing setup: See "Hit Testing API" section
- Object anchoring: See "Anchors API" section
- Input handling: See "Input Handling" section

#### FastAPI Backend
- Request handling: See "Request Handling" in fastapi-reference.md
- WebSocket sync: See "WebSocket Support" section
- File uploads: See "File Handling" section
- Session management: See "Common Patterns for AR/XR Applications"

#### Environment Setup
- Port configuration: See "Port Forwarding" in codespaces-reference.md
- Dev container: See "Dev Container Configuration" section
- Service orchestration: See "Running Multiple Services" section

### Documentation Quality Standards
- **Accuracy**: Verify against official sources
- **Completeness**: Include all necessary details
- **Clarity**: Use clear, concise language
- **Practicality**: Focus on implementation, not theory
- **Currency**: Note versions and update dates