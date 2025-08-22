# AI Frame Deployment and Orchestration Guide

## Overview
This guide covers deployment strategies for the AI Frame persistent AR platform, including local development, GitHub Codespaces, and production deployment options.

## Table of Contents
1. [Service Architecture](#service-architecture)
2. [Development Setup](#development-setup)
3. [GitHub Codespaces Deployment](#github-codespaces-deployment)
4. [Docker Deployment](#docker-deployment)
5. [tmux Orchestration](#tmux-orchestration)
6. [Production Deployment](#production-deployment)
7. [Monitoring and Logs](#monitoring-and-logs)

## Service Architecture

### Core Services
```
┌─────────────────────────────────────────┐
│          AI Frame Services              │
├─────────────────────────────────────────┤
│ 1. FastAPI Server (Port 3001)           │
│    - Object persistence API             │
│    - Session management                 │
│    - WebSocket sync                     │
│                                         │
│ 2. WebXR HTTPS Server (Port 8443)      │
│    - AR/VR interface                   │
│    - Self-signed SSL                   │
│    - Static file serving               │
│                                         │
│ 3. Mobile HTTP Server (Port 8080)      │
│    - Mobile capture interface          │
│    - QR code launcher                  │
│    - Non-SSL fallback                  │
└─────────────────────────────────────────┘
```

### Port Configuration
- **3001**: FastAPI backend server
- **8443**: HTTPS WebXR interface (required for WebXR)
- **8080**: HTTP mobile/desktop interface

## Development Setup

### Prerequisites
```bash
# Required software
- Node.js 18+ 
- Python 3.11+
- npm/yarn
- Git
- tmux (recommended)
- Docker (optional)
```

### Initial Setup
```bash
# Clone repository
git clone <repository-url>
cd ai-frame/first-attempt

# Install dependencies
npm install
pip install -r server/requirements.txt

# Generate SSL certificates
./setup.sh
```

### Quick Start Script
```bash
#!/bin/bash
# run-services.sh

echo "AI Frame Service Orchestrator"
echo "============================="
echo "Select deployment method:"
echo "1. Docker Compose"
echo "2. tmux (Development)"
echo "3. Direct (Foreground)"

read -p "Choice [1-3]: " choice

case $choice in
    1)
        docker-compose up -d
        ;;
    2)
        ./start-tmux.sh
        ;;
    3)
        ./start-direct.sh
        ;;
esac
```

## GitHub Codespaces Deployment

### Automatic Configuration
```bash
# Environment detection
if [ -n "$CODESPACES" ]; then
    echo "GitHub Codespaces detected"
    
    # Get Codespace URLs
    CODESPACE_NAME="${CODESPACE_NAME}"
    DOMAIN="app.github.dev"
    
    export API_URL="https://${CODESPACE_NAME}-3001.${DOMAIN}"
    export WEBXR_URL="https://${CODESPACE_NAME}-8443.${DOMAIN}"
    export MOBILE_URL="https://${CODESPACE_NAME}-8080.${DOMAIN}"
fi
```

### Port Visibility Configuration
```bash
# Set ports to public for Quest access
gh codespace ports visibility 8443:public
gh codespace ports visibility 3001:public
gh codespace ports visibility 8080:public

# Verify port configuration
gh codespace ports
```

### Quest Launcher URL Generation
```bash
#!/bin/bash
# get-launcher-url.sh

if [ -n "$CODESPACES" ]; then
    BASE_URL="https://${CODESPACE_NAME}-8443.app.github.dev"
    LAUNCHER_URL="https://www.oculus.com/open_url/?url=${BASE_URL}"
    
    echo "Quest Launcher URL:"
    echo "$LAUNCHER_URL"
    echo "$LAUNCHER_URL" > launcher-url.txt
    
    # Generate QR code
    qrencode -o launcher-qr.png "$LAUNCHER_URL"
fi
```

## Docker Deployment

### Docker Compose Configuration
```yaml
# docker-compose.yml
version: '3.8'

services:
  api:
    build: ./server
    ports:
      - "3001:3001"
    volumes:
      - ./server/uploads:/app/uploads
      - ./server/sessions:/app/sessions
    environment:
      - PYTHONUNBUFFERED=1
      - CORS_ORIGINS=*
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3001/health"]
      interval: 30s
      timeout: 10s
      retries: 3

  webxr:
    image: node:18-alpine
    working_dir: /app
    volumes:
      - .:/app
    ports:
      - "8443:8443"
    command: npx http-server -S -C certs/cert.pem -K certs/key.pem -p 8443
    depends_on:
      - api

  mobile:
    image: node:18-alpine
    working_dir: /app
    volumes:
      - .:/app
    ports:
      - "8080:8080"
    command: npx http-server -p 8080
    depends_on:
      - api
```

### Docker Commands
```bash
# Build and start services
docker-compose up -d

# View logs
docker-compose logs -f

# Stop services
docker-compose down

# Rebuild after changes
docker-compose up -d --build

# Clean volumes
docker-compose down -v
```

## tmux Orchestration

### tmux Session Setup
```bash
#!/bin/bash
# start-tmux.sh

SESSION="aiframe"

# Kill existing session
tmux kill-session -t $SESSION 2>/dev/null

# Create new session
tmux new-session -d -s $SESSION

# API Server (Pane 0)
tmux send-keys -t $SESSION:0 "cd server && python3 api_server.py" C-m

# Split horizontally for WebXR
tmux split-window -h -t $SESSION:0
tmux send-keys -t $SESSION:0.1 "npx http-server -S -C certs/cert.pem -K certs/key.pem -p 8443" C-m

# Split vertically for Mobile
tmux split-window -v -t $SESSION:0.1
tmux send-keys -t $SESSION:0.2 "npx http-server -p 8080" C-m

# Create monitoring pane
tmux split-window -v -t $SESSION:0.0
tmux send-keys -t $SESSION:0.3 "./monitor-logs.sh" C-m

# Attach to session
tmux attach-session -t $SESSION
```

### tmux Commands Reference
```bash
# List sessions
tmux ls

# Attach to session
tmux attach -t aiframe

# Detach from session
Ctrl+B, D

# Switch panes
Ctrl+B, Arrow Keys

# Kill pane
Ctrl+B, X

# Create new window
Ctrl+B, C

# Switch windows
Ctrl+B, Number
```

## Production Deployment

### System Requirements
```yaml
# Minimum Requirements
CPU: 2 cores
RAM: 4GB
Storage: 20GB
Network: 100Mbps

# Recommended
CPU: 4 cores
RAM: 8GB
Storage: 50GB SSD
Network: 1Gbps
```

### Nginx Reverse Proxy
```nginx
# /etc/nginx/sites-available/aiframe

upstream api_backend {
    server localhost:3001;
}

server {
    listen 443 ssl http2;
    server_name ar.example.com;
    
    ssl_certificate /etc/ssl/certs/aiframe.crt;
    ssl_certificate_key /etc/ssl/private/aiframe.key;
    
    # WebXR Interface
    location / {
        proxy_pass http://localhost:8443;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
    
    # API Backend
    location /api {
        proxy_pass http://api_backend;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
    
    # WebSocket Support
    location /ws {
        proxy_pass http://api_backend;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
```

### Systemd Service Configuration
```ini
# /etc/systemd/system/aiframe-api.service
[Unit]
Description=AI Frame API Server
After=network.target

[Service]
Type=simple
User=aiframe
WorkingDirectory=/opt/aiframe/server
Environment="PATH=/opt/aiframe/venv/bin"
ExecStart=/opt/aiframe/venv/bin/uvicorn api_server:app --host 0.0.0.0 --port 3001 --workers 4
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
```

### Process Management with PM2
```javascript
// ecosystem.config.js
module.exports = {
  apps: [
    {
      name: 'aiframe-api',
      script: 'uvicorn',
      args: 'api_server:app --host 0.0.0.0 --port 3001',
      cwd: './server',
      interpreter: 'python3',
      instances: 4,
      exec_mode: 'cluster'
    },
    {
      name: 'aiframe-webxr',
      script: 'npx',
      args: 'http-server -S -C certs/cert.pem -K certs/key.pem -p 8443',
      cwd: './'
    },
    {
      name: 'aiframe-mobile',
      script: 'npx',
      args: 'http-server -p 8080',
      cwd: './'
    }
  ]
};
```

## Monitoring and Logs

### Log Aggregation Script
```bash
#!/bin/bash
# monitor-logs.sh

# Create logs directory
mkdir -p logs

# Tail all service logs
tail -f \
    logs/api.log \
    logs/webxr.log \
    logs/mobile.log \
    2>/dev/null | while read line; do
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $line"
done
```

### Health Check Endpoints
```python
# API Server health check
@app.get("/health")
async def health_check():
    return {
        "status": "healthy",
        "timestamp": datetime.now(),
        "services": {
            "api": "running",
            "database": check_db_connection(),
            "storage": check_storage_space()
        }
    }

@app.get("/metrics")
async def metrics():
    return {
        "requests_total": request_counter,
        "active_sessions": len(active_sessions),
        "objects_stored": count_objects(),
        "uptime": get_uptime()
    }
```

### Monitoring Dashboard
```bash
# Simple monitoring with curl
while true; do
    clear
    echo "AI Frame Service Monitor"
    echo "========================"
    
    # Check API
    curl -s http://localhost:3001/health | jq .
    
    # Check WebXR
    curl -s -o /dev/null -w "WebXR: %{http_code}\n" https://localhost:8443
    
    # Check Mobile
    curl -s -o /dev/null -w "Mobile: %{http_code}\n" http://localhost:8080
    
    # System resources
    echo ""
    echo "System Resources:"
    free -h | grep Mem
    df -h | grep -E "/$|/app"
    
    sleep 5
done
```

## Environment Variables

### Configuration File
```bash
# .env
# API Configuration
API_HOST=0.0.0.0
API_PORT=3001
API_WORKERS=4

# CORS Settings
CORS_ORIGINS=https://localhost:8443,https://*.github.dev
CORS_CREDENTIALS=true

# Storage
UPLOAD_DIR=/app/uploads
SESSION_DIR=/app/sessions
MAX_FILE_SIZE=104857600

# Security
SECRET_KEY=your-secret-key-here
JWT_ALGORITHM=HS256
TOKEN_EXPIRE_MINUTES=60

# External Services
REDIS_URL=redis://localhost:6379
DATABASE_URL=postgresql://user:pass@localhost/aiframe

# Feature Flags
ENABLE_WEBSOCKET=true
ENABLE_METRICS=true
ENABLE_CACHE=true
```

### Loading Environment Variables
```python
# config.py
from pydantic import BaseSettings

class Settings(BaseSettings):
    api_host: str = "0.0.0.0"
    api_port: int = 3001
    cors_origins: list[str] = ["*"]
    upload_dir: str = "./uploads"
    session_dir: str = "./sessions"
    max_file_size: int = 100 * 1024 * 1024
    
    class Config:
        env_file = ".env"

settings = Settings()
```

## SSL Certificate Management

### Self-Signed Certificates (Development)
```bash
#!/bin/bash
# generate-certs.sh

mkdir -p certs
cd certs

# Generate private key
openssl genrsa -out key.pem 2048

# Generate certificate
openssl req -new -x509 -key key.pem -out cert.pem -days 365 \
    -subj "/C=US/ST=State/L=City/O=Organization/CN=localhost"

# Verify certificate
openssl x509 -in cert.pem -text -noout
```

### Let's Encrypt (Production)
```bash
# Install certbot
apt-get install certbot python3-certbot-nginx

# Generate certificate
certbot --nginx -d ar.example.com

# Auto-renewal
certbot renew --dry-run
```

## Troubleshooting

### Common Issues

#### Port Already in Use
```bash
# Find process using port
lsof -i :3001
netstat -tlnp | grep 3001

# Kill process
kill -9 <PID>
```

#### CORS Errors
```python
# Ensure proper CORS configuration
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Be more specific in production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"]
)
```

#### WebXR Not Working
```bash
# Check HTTPS certificate
openssl s_client -connect localhost:8443 -showcerts

# Verify WebXR browser support
navigator.xr.isSessionSupported('immersive-ar')
```

#### Session Persistence Issues
```bash
# Check storage permissions
ls -la server/sessions/
chmod 755 server/sessions/

# Verify session cleanup
find server/sessions -type f -mtime +7 -delete
```

## Performance Optimization

### Service Tuning
```python
# Uvicorn configuration
uvicorn api_server:app \
    --workers 4 \
    --loop uvloop \
    --limit-concurrency 1000 \
    --limit-max-requests 10000 \
    --timeout-keep-alive 5
```

### Resource Limits
```yaml
# docker-compose.yml
services:
  api:
    deploy:
      resources:
        limits:
          cpus: '2'
          memory: 2G
        reservations:
          cpus: '1'
          memory: 1G
```

### Caching Strategy
```python
# Redis caching
import redis
from functools import wraps

redis_client = redis.Redis(host='localhost', port=6379)

def cache_result(expiration=300):
    def decorator(func):
        @wraps(func)
        async def wrapper(*args, **kwargs):
            cache_key = f"{func.__name__}:{str(args)}:{str(kwargs)}"
            cached = redis_client.get(cache_key)
            if cached:
                return json.loads(cached)
            result = await func(*args, **kwargs)
            redis_client.setex(cache_key, expiration, json.dumps(result))
            return result
        return wrapper
    return decorator
```

## Security Best Practices

### API Security
- Use HTTPS everywhere
- Implement rate limiting
- Validate all inputs
- Use secure session tokens
- Regular security updates

### Container Security
```dockerfile
# Use minimal base image
FROM python:3.11-slim

# Run as non-root user
RUN useradd -m -u 1000 appuser
USER appuser

# Copy only necessary files
COPY --chown=appuser:appuser . /app
```

### Network Security
```bash
# Firewall configuration
ufw allow 22/tcp
ufw allow 443/tcp
ufw allow 3001/tcp
ufw enable
```

## Backup and Recovery

### Automated Backups
```bash
#!/bin/bash
# backup.sh

BACKUP_DIR="/backups/aiframe"
DATE=$(date +%Y%m%d_%H%M%S)

# Backup sessions and uploads
tar -czf "$BACKUP_DIR/sessions_$DATE.tar.gz" server/sessions/
tar -czf "$BACKUP_DIR/uploads_$DATE.tar.gz" server/uploads/

# Clean old backups (keep 7 days)
find $BACKUP_DIR -type f -mtime +7 -delete
```

### Recovery Procedure
```bash
# Restore from backup
tar -xzf /backups/aiframe/sessions_20250115_120000.tar.gz -C server/
tar -xzf /backups/aiframe/uploads_20250115_120000.tar.gz -C server/

# Verify restoration
ls -la server/sessions/
ls -la server/uploads/
```

## References
- [Docker Documentation](https://docs.docker.com/)
- [tmux Manual](https://man7.org/linux/man-pages/man1/tmux.1.html)
- [Nginx Documentation](https://nginx.org/en/docs/)
- [PM2 Documentation](https://pm2.keymetrics.io/)
- [GitHub Codespaces](https://docs.github.com/en/codespaces)