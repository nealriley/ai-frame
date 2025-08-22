# GitHub Codespaces Deployment Guide for AI Frame

## Overview
This guide provides the optimal deployment method for the AI Frame project in GitHub Codespaces, leveraging automatic port forwarding and public URL exposure for WebXR access from Meta Quest and other AR/VR devices.

## Deployment Architecture

### Service Configuration
The AI Frame project consists of three main services:

1. **FastAPI Backend** (Port 3001)
   - REST API for object persistence
   - WebSocket support for real-time sync
   - Session management
   - Media upload handling

2. **WebXR HTTPS Server** (Port 8443)
   - Serves AR/VR interface
   - Requires HTTPS for WebXR API access
   - Self-signed certificates auto-generated
   - Main entry point for Quest devices

3. **Mobile HTTP Server** (Port 8080)
   - Alternative interface for phones
   - Fallback for non-WebXR devices
   - Testing and debugging interface

## Optimal Deployment Method: tmux Sessions

### Why tmux is Optimal for Codespaces
- **Persistent Sessions**: Services continue running when disconnected
- **Multi-pane View**: Monitor all services simultaneously
- **Resource Efficient**: Lower overhead than Docker in Codespaces
- **Quick Restart**: Easy to stop/start individual services
- **Log Visibility**: Real-time output from all services

### Deployment Steps

#### 1. Start All Services
```bash
cd /workspaces/ai-frame/first-attempt
./run-services.sh
# Choose option 2 (tmux sessions)
```

#### 2. Monitor Services
```bash
tmux attach -t aiframe
# Navigate panes: Ctrl+B then arrow keys
# Detach: Ctrl+B then D
```

#### 3. Get Quest Access URL
```bash
./get-launcher-url.sh
# Automatically generates Quest-compatible launcher URL
```

## Port Configuration

### Automatic Port Exposure
Codespaces automatically detects and forwards ports when services start. The project is configured to:

1. **Auto-forward** ports 3001, 8080, 8443
2. **Set visibility** appropriately for each service
3. **Generate public URLs** for external access

### Manual Port Configuration
If ports aren't automatically exposed:

```bash
# Via GitHub CLI
gh codespace ports visibility 8443:public -c $CODESPACE_NAME
gh codespace ports visibility 3001:public -c $CODESPACE_NAME
gh codespace ports visibility 8080:public -c $CODESPACE_NAME

# Or use the Ports panel in VS Code/Browser
```

### Port Visibility Settings
- **8443 (WebXR)**: PUBLIC - Required for Quest access
- **3001 (API)**: PUBLIC - Required for cross-origin requests
- **8080 (Mobile)**: PUBLIC - Optional, for mobile testing

## Environment Variables

### Codespaces Environment Detection
The project automatically detects Codespaces environment using:

```bash
# Available in Codespaces
$CODESPACES                              # "true"
$CODESPACE_NAME                           # e.g., "psychic-spork-r74rr59pp52qxr"
$GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN # "app.github.dev"
$GITHUB_USER                              # Your GitHub username
$GITHUB_TOKEN                             # Authentication token
```

### Dynamic URL Generation
Services automatically construct Codespaces URLs:

```javascript
// JavaScript example
if (process.env.CODESPACES === 'true') {
    const apiUrl = `https://${process.env.CODESPACE_NAME}-3001.${process.env.GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN}`;
}
```

```python
# Python example
import os
if os.environ.get('CODESPACES') == 'true':
    codespace_name = os.environ['CODESPACE_NAME']
    domain = os.environ.get('GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN', 'app.github.dev')
    api_url = f"https://{codespace_name}-3001.{domain}"
```

## URL Structure

### Codespaces URL Format
```
https://{CODESPACE_NAME}-{PORT}.{DOMAIN}
```

Example URLs for a Codespace named `psychic-spork-r74rr59pp52qxr`:
- WebXR: `https://psychic-spork-r74rr59pp52qxr-8443.app.github.dev`
- API: `https://psychic-spork-r74rr59pp52qxr-3001.app.github.dev`
- Mobile: `https://psychic-spork-r74rr59pp52qxr-8080.app.github.dev`

### Meta Quest Launcher URL
The project generates Quest-compatible launcher URLs:
```
https://www.oculus.com/open_url/?url={URL_ENCODED_CODESPACE_URL}
```

## Command-Line Tools

### Essential Commands

#### Service Management
```bash
# Start all services
./run-services.sh

# View running services
tmux ls
tmux attach -t aiframe

# Stop all services
tmux kill-session -t aiframe

# Restart individual service (while attached to tmux)
# Navigate to pane and press Ctrl+C, then up arrow + Enter
```

#### Port Management
```bash
# List forwarded ports
gh codespace ports

# Forward a specific port
gh codespace ports forward 3001:3001

# Set port visibility
gh codespace ports visibility 8443:public
```

#### URL Generation
```bash
# Get Quest launcher URL
./get-launcher-url.sh

# Manual URL construction
echo "https://${CODESPACE_NAME}-8443.${GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN}"
```

#### Debugging
```bash
# Check service status
curl http://localhost:3001/status
curl -k https://localhost:8443

# View logs
tmux attach -t aiframe
# Or for specific service
docker logs aiframe-api (if using Docker)

# Check port usage
lsof -i :3001
netstat -tlnp | grep 8443
```

## devcontainer.json Configuration

### Recommended Configuration
```json
{
  "name": "AI Frame WebXR",
  "image": "mcr.microsoft.com/devcontainers/python:3.11",
  
  "features": {
    "ghcr.io/devcontainers/features/node:1": {
      "version": "18"
    }
  },
  
  "forwardPorts": [3001, 8080, 8443],
  
  "portsAttributes": {
    "3001": {
      "label": "FastAPI Backend",
      "onAutoForward": "notify",
      "visibility": "public"
    },
    "8443": {
      "label": "WebXR HTTPS",
      "onAutoForward": "notify",
      "protocol": "https",
      "visibility": "public"
    },
    "8080": {
      "label": "Mobile Interface",
      "onAutoForward": "openBrowser",
      "visibility": "public"
    }
  },
  
  "postCreateCommand": "cd first-attempt && npm install && cd server && pip install -r requirements.txt",
  
  "postStartCommand": "cd first-attempt && ./run-services.sh",
  
  "customizations": {
    "vscode": {
      "extensions": [
        "ms-python.python",
        "dbaeumer.vscode-eslint"
      ]
    }
  },
  
  "remoteEnv": {
    "CODESPACES": "true"
  }
}
```

## Troubleshooting

### Common Issues and Solutions

#### 1. Ports Not Accessible from Quest
**Problem**: Quest can't connect to Codespace URL
**Solution**:
```bash
# Ensure ports are public
gh codespace ports visibility 8443:public -c $CODESPACE_NAME
gh codespace ports visibility 3001:public -c $CODESPACE_NAME
```

#### 2. Services Not Starting
**Problem**: tmux session fails to start services
**Solution**:
```bash
# Check for port conflicts
lsof -i :3001
lsof -i :8443
lsof -i :8080

# Kill conflicting processes
kill -9 $(lsof -ti:3001)

# Restart services
./run-services.sh
```

#### 3. Certificate Errors
**Problem**: Browser shows certificate warning
**Solution**:
- This is expected with self-signed certificates
- Click "Advanced" → "Proceed to site"
- For Quest: Accept certificate when prompted

#### 4. CORS Errors
**Problem**: Cross-origin requests blocked
**Solution**:
- Ensure API server has proper CORS headers
- Check that all ports are set to PUBLIC
- Verify URLs match Codespace domain

#### 5. WebXR Not Available
**Problem**: WebXR APIs not accessible
**Solution**:
- Must use HTTPS (port 8443)
- Ensure using compatible browser (Quest Browser)
- Check browser flags/settings for WebXR

## Performance Optimization

### Codespace Machine Types
For optimal performance, use:
- **Minimum**: 4 cores, 8 GB RAM
- **Recommended**: 8 cores, 16 GB RAM
- **Heavy Development**: 16 cores, 32 GB RAM

### Service Optimization
```bash
# Reduce resource usage
# In server/api_server.py, limit workers:
uvicorn.run(app, host="0.0.0.0", port=3001, workers=2)

# Use production mode for frontend
NODE_ENV=production npx http-server
```

## Security Considerations

### Port Visibility Best Practices
- **Development**: PUBLIC for testing with Quest
- **Production**: Use authentication tokens
- **Sensitive Data**: Keep API endpoints private, use GITHUB_TOKEN

### HTTPS Configuration
- Self-signed certificates are acceptable for development
- For production, use proper SSL certificates
- Consider using Cloudflare Tunnel for secure access

## Deployment Checklist

- [ ] Start Codespace
- [ ] Run `./run-services.sh` (choose tmux option)
- [ ] Set ports 8443, 3001, 8080 to PUBLIC
- [ ] Generate Quest URL with `./get-launcher-url.sh`
- [ ] Test WebXR access from Quest browser
- [ ] Verify API endpoints are accessible
- [ ] Check real-time synchronization
- [ ] Monitor service logs in tmux

## Quick Reference Card

```bash
# Start everything
cd /workspaces/ai-frame/first-attempt && ./run-services.sh

# Get Quest URL
./get-launcher-url.sh

# Monitor services
tmux attach -t aiframe

# Make ports public
gh codespace ports visibility 8443:public
gh codespace ports visibility 3001:public
gh codespace ports visibility 8080:public

# Test endpoints
curl http://localhost:3001/status
curl -k https://localhost:8443

# Stop everything
tmux kill-session -t aiframe
```

## Summary
The optimal deployment for AI Frame in GitHub Codespaces uses tmux sessions for service orchestration, automatic port forwarding with public visibility for WebXR access, and dynamic URL generation for Quest compatibility. This approach provides a seamless development experience with minimal configuration while maintaining full access from AR/VR devices.