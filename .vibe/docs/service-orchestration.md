# Service Orchestration Documentation

## Overview
Service orchestration in AI Frame manages multiple interconnected services including the WebXR frontend, FastAPI backend, and supporting infrastructure. This document covers patterns for running, monitoring, and managing these services effectively.

## Service Architecture

### Service Topology
```
┌─────────────────────────────────────────────────────────┐
│                   Service Orchestration                  │
├─────────────────────────────────────────────────────────┤
│                                                          │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  │
│  │  WebXR HTTPS │  │  API Server  │  │ Mobile HTTP  │  │
│  │   Port 8443  │  │  Port 3001   │  │  Port 8080   │  │
│  │              │  │              │  │              │  │
│  │  Node.js     │  │  Python      │  │  Node.js     │  │
│  │  http-server │  │  FastAPI     │  │  http-server │  │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘  │
│         │                  │                  │          │
│         └──────────────────┼──────────────────┘          │
│                           │                              │
│                    Shared Resources                      │
│  ┌────────────────────────┴────────────────────────┐    │
│  │  • File System (sessions, uploads)              │    │
│  │  • SSL Certificates                             │    │
│  │  • Configuration Files                          │    │
│  │  • Logs                                         │    │
│  └──────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────┘
```

## Orchestration Methods

### 1. tmux-Based Orchestration

#### Setup Script
```bash
#!/bin/bash
# run-services.sh - Main orchestration script

set -e  # Exit on error

# Configuration
SESSION_NAME="aiframe"
API_PORT=3001
WEBXR_PORT=8443
MOBILE_PORT=8080

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Check dependencies
check_dependencies() {
    log_info "Checking dependencies..."
    
    # Check Python
    if ! command -v python3 &> /dev/null; then
        log_error "Python 3 is not installed"
        exit 1
    fi
    
    # Check Node.js
    if ! command -v node &> /dev/null; then
        log_error "Node.js is not installed"
        exit 1
    fi
    
    # Check tmux
    if ! command -v tmux &> /dev/null; then
        log_error "tmux is not installed"
        exit 1
    fi
    
    log_info "All dependencies satisfied"
}

# Setup environment
setup_environment() {
    log_info "Setting up environment..."
    
    # Create necessary directories
    mkdir -p server/uploads server/sessions logs certs
    
    # Generate SSL certificates if not present
    if [ ! -f certs/cert.pem ]; then
        log_info "Generating SSL certificates..."
        openssl req -x509 -newkey rsa:4096 \
            -keyout certs/key.pem \
            -out certs/cert.pem \
            -days 365 -nodes \
            -subj "/C=US/ST=State/L=City/O=Organization/CN=localhost"
    fi
    
    # Install Python dependencies
    if [ ! -d "server/venv" ]; then
        log_info "Creating Python virtual environment..."
        python3 -m venv server/venv
        source server/venv/bin/activate
        pip install -r server/requirements.txt
    fi
    
    # Install Node dependencies
    if [ ! -d "node_modules" ]; then
        log_info "Installing Node dependencies..."
        npm install
    fi
}

# Start services in tmux
start_tmux_services() {
    log_info "Starting services in tmux..."
    
    # Kill existing session if it exists
    tmux kill-session -t $SESSION_NAME 2>/dev/null || true
    
    # Create new session
    tmux new-session -d -s $SESSION_NAME -n services
    
    # Split window into panes
    # Layout:
    # +------------------+------------------+
    # |                  |                  |
    # |   API Server     |   WebXR Server   |
    # |                  |                  |
    # +------------------+------------------+
    # |                  |                  |
    # |  Mobile Server   |   Monitoring     |
    # |                  |                  |
    # +------------------+------------------+
    
    # Start API server (pane 0)
    tmux send-keys -t $SESSION_NAME:services.0 "
        cd server
        source venv/bin/activate 2>/dev/null || true
        echo 'Starting API Server on port $API_PORT...'
        python3 api_server.py 2>&1 | tee ../logs/api.log
    " C-m
    
    # Split horizontally and start WebXR server (pane 1)
    tmux split-window -h -t $SESSION_NAME:services
    tmux send-keys -t $SESSION_NAME:services.1 "
        echo 'Starting WebXR HTTPS Server on port $WEBXR_PORT...'
        npx http-server -S -C certs/cert.pem -K certs/key.pem -p $WEBXR_PORT --cors 2>&1 | tee logs/webxr.log
    " C-m
    
    # Split vertically and start Mobile server (pane 2)
    tmux split-window -v -t $SESSION_NAME:services.0
    tmux send-keys -t $SESSION_NAME:services.2 "
        echo 'Starting Mobile HTTP Server on port $MOBILE_PORT...'
        npx http-server -p $MOBILE_PORT --cors 2>&1 | tee logs/mobile.log
    " C-m
    
    # Split vertically and start monitoring (pane 3)
    tmux split-window -v -t $SESSION_NAME:services.1
    tmux send-keys -t $SESSION_NAME:services.3 "
        echo 'Starting service monitor...'
        watch -n 5 './monitor-status.sh'
    " C-m
    
    # Balance panes
    tmux select-layout -t $SESSION_NAME:services tiled
    
    log_info "Services started successfully"
}

# Main execution
main() {
    log_info "AI Frame Service Orchestrator"
    log_info "=============================="
    
    check_dependencies
    setup_environment
    
    echo ""
    echo "Select deployment method:"
    echo "1. tmux (Development)"
    echo "2. Docker Compose"
    echo "3. Direct (Foreground)"
    echo "4. Systemd (Production)"
    
    read -p "Choice [1-4]: " choice
    
    case $choice in
        1)
            start_tmux_services
            echo ""
            log_info "Services are running in tmux session: $SESSION_NAME"
            log_info "To attach: tmux attach -t $SESSION_NAME"
            log_info "To detach: Ctrl+B, D"
            log_info "To stop: tmux kill-session -t $SESSION_NAME"
            ;;
        2)
            start_docker_services
            ;;
        3)
            start_direct_services
            ;;
        4)
            start_systemd_services
            ;;
        *)
            log_error "Invalid choice"
            exit 1
            ;;
    esac
    
    # Show access URLs
    show_access_urls
}

# Show access URLs
show_access_urls() {
    echo ""
    log_info "Access URLs:"
    log_info "============"
    
    if [ -n "$CODESPACES" ]; then
        # GitHub Codespaces URLs
        echo "WebXR: https://${CODESPACE_NAME}-${WEBXR_PORT}.app.github.dev"
        echo "API:   https://${CODESPACE_NAME}-${API_PORT}.app.github.dev"
        echo "Mobile: https://${CODESPACE_NAME}-${MOBILE_PORT}.app.github.dev"
    else
        # Local URLs
        echo "WebXR: https://localhost:${WEBXR_PORT}"
        echo "API:   http://localhost:${API_PORT}"
        echo "Mobile: http://localhost:${MOBILE_PORT}"
        
        # Show local IP for network access
        LOCAL_IP=$(hostname -I | awk '{print $1}')
        if [ -n "$LOCAL_IP" ]; then
            echo ""
            echo "Network Access:"
            echo "WebXR: https://${LOCAL_IP}:${WEBXR_PORT}"
            echo "API:   http://${LOCAL_IP}:${API_PORT}"
            echo "Mobile: http://${LOCAL_IP}:${MOBILE_PORT}"
        fi
    fi
}

# Run main function
main "$@"
```

#### Service Monitoring Script
```bash
#!/bin/bash
# monitor-status.sh - Service health monitoring

# Check service status
check_service() {
    local port=$1
    local name=$2
    
    if lsof -i :$port > /dev/null 2>&1; then
        echo "✓ $name (Port $port)"
    else
        echo "✗ $name (Port $port) - NOT RUNNING"
    fi
}

# Display header
clear
echo "================================"
echo "   AI Frame Service Monitor"
echo "================================"
echo ""
echo "Timestamp: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

# Check services
echo "Service Status:"
echo "---------------"
check_service 3001 "API Server"
check_service 8443 "WebXR HTTPS"
check_service 8080 "Mobile HTTP"

# Check resource usage
echo ""
echo "Resource Usage:"
echo "---------------"

# Memory usage
echo -n "Memory: "
free -h | grep "^Mem:" | awk '{print $3 " / " $2 " (" int($3/$2 * 100) "%)"}'

# CPU usage
echo -n "CPU: "
top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1

# Disk usage
echo -n "Disk: "
df -h . | tail -1 | awk '{print $3 " / " $2 " (" $5 ")"}'

# Connection count
echo ""
echo "Connections:"
echo "------------"
echo -n "API: "
netstat -an | grep :3001 | grep ESTABLISHED | wc -l
echo -n "WebXR: "
netstat -an | grep :8443 | grep ESTABLISHED | wc -l

# Recent logs
echo ""
echo "Recent Errors:"
echo "--------------"
tail -n 5 logs/api.log 2>/dev/null | grep ERROR || echo "No recent errors"
```

### 2. Docker Compose Orchestration

#### docker-compose.yml
```yaml
version: '3.8'

services:
  # FastAPI Backend Service
  api:
    build:
      context: ./server
      dockerfile: Dockerfile
    container_name: aiframe-api
    ports:
      - "3001:3001"
    volumes:
      - ./server/uploads:/app/uploads
      - ./server/sessions:/app/sessions
      - ./logs:/app/logs
    environment:
      - PYTHONUNBUFFERED=1
      - API_HOST=0.0.0.0
      - API_PORT=3001
      - CORS_ORIGINS=https://localhost:8443,http://localhost:8080
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3001/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
    restart: unless-stopped
    networks:
      - aiframe-network

  # WebXR HTTPS Service
  webxr:
    image: node:18-alpine
    container_name: aiframe-webxr
    working_dir: /app
    volumes:
      - .:/app
      - ./certs:/app/certs:ro
    ports:
      - "8443:8443"
    command: >
      sh -c "
        npm install http-server &&
        npx http-server -S -C certs/cert.pem -K certs/key.pem -p 8443 --cors
      "
    healthcheck:
      test: ["CMD", "wget", "--no-check-certificate", "-q", "--spider", "https://localhost:8443"]
      interval: 30s
      timeout: 10s
      retries: 3
    depends_on:
      - api
    restart: unless-stopped
    networks:
      - aiframe-network

  # Mobile HTTP Service
  mobile:
    image: node:18-alpine
    container_name: aiframe-mobile
    working_dir: /app
    volumes:
      - .:/app
    ports:
      - "8080:8080"
    command: >
      sh -c "
        npm install http-server &&
        npx http-server -p 8080 --cors
      "
    healthcheck:
      test: ["CMD", "wget", "-q", "--spider", "http://localhost:8080"]
      interval: 30s
      timeout: 10s
      retries: 3
    depends_on:
      - api
    restart: unless-stopped
    networks:
      - aiframe-network

  # Optional: Redis for caching/sessions
  redis:
    image: redis:7-alpine
    container_name: aiframe-redis
    ports:
      - "6379:6379"
    volumes:
      - redis-data:/data
    command: redis-server --appendonly yes
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 30s
      timeout: 10s
      retries: 3
    restart: unless-stopped
    networks:
      - aiframe-network

  # Optional: Nginx reverse proxy
  nginx:
    image: nginx:alpine
    container_name: aiframe-nginx
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx/nginx.conf:/etc/nginx/nginx.conf:ro
      - ./certs:/etc/nginx/certs:ro
    depends_on:
      - api
      - webxr
      - mobile
    restart: unless-stopped
    networks:
      - aiframe-network

networks:
  aiframe-network:
    driver: bridge

volumes:
  redis-data:
```

#### Docker Management Script
```bash
#!/bin/bash
# docker-services.sh - Docker Compose management

# Commands
case "$1" in
    start)
        echo "Starting services with Docker Compose..."
        docker-compose up -d
        docker-compose ps
        ;;
    
    stop)
        echo "Stopping services..."
        docker-compose down
        ;;
    
    restart)
        echo "Restarting services..."
        docker-compose restart
        ;;
    
    logs)
        docker-compose logs -f $2
        ;;
    
    status)
        docker-compose ps
        ;;
    
    build)
        echo "Building containers..."
        docker-compose build --no-cache
        ;;
    
    clean)
        echo "Cleaning up..."
        docker-compose down -v
        docker system prune -f
        ;;
    
    *)
        echo "Usage: $0 {start|stop|restart|logs|status|build|clean}"
        exit 1
        ;;
esac
```

### 3. Process Manager (PM2)

#### ecosystem.config.js
```javascript
module.exports = {
  apps: [
    {
      name: 'aiframe-api',
      script: 'python3',
      args: 'api_server.py',
      cwd: './server',
      interpreter: '/usr/bin/python3',
      env: {
        PYTHONUNBUFFERED: '1',
        API_PORT: '3001'
      },
      max_memory_restart: '500M',
      error_file: './logs/api-error.log',
      out_file: './logs/api-out.log',
      log_file: './logs/api-combined.log',
      time: true
    },
    {
      name: 'aiframe-webxr',
      script: 'npx',
      args: 'http-server -S -C certs/cert.pem -K certs/key.pem -p 8443 --cors',
      cwd: './',
      max_memory_restart: '200M',
      error_file: './logs/webxr-error.log',
      out_file: './logs/webxr-out.log',
      log_file: './logs/webxr-combined.log',
      time: true
    },
    {
      name: 'aiframe-mobile',
      script: 'npx',
      args: 'http-server -p 8080 --cors',
      cwd: './',
      max_memory_restart: '200M',
      error_file: './logs/mobile-error.log',
      out_file: './logs/mobile-out.log',
      log_file: './logs/mobile-combined.log',
      time: true
    }
  ],

  deploy: {
    production: {
      user: 'aiframe',
      host: 'production-server',
      ref: 'origin/main',
      repo: 'git@github.com:user/aiframe.git',
      path: '/var/www/aiframe',
      'post-deploy': 'npm install && pm2 reload ecosystem.config.js --env production'
    }
  }
};
```

#### PM2 Management Commands
```bash
# Start all services
pm2 start ecosystem.config.js

# Stop all services
pm2 stop all

# Restart services
pm2 restart all

# View logs
pm2 logs

# Monitor services
pm2 monit

# Save current process list
pm2 save

# Setup startup script
pm2 startup
```

### 4. Systemd Services (Production)

#### API Service Unit
```ini
# /etc/systemd/system/aiframe-api.service
[Unit]
Description=AI Frame API Server
After=network.target

[Service]
Type=simple
User=aiframe
Group=aiframe
WorkingDirectory=/opt/aiframe/server
Environment="PATH=/opt/aiframe/venv/bin"
Environment="PYTHONUNBUFFERED=1"
ExecStart=/opt/aiframe/venv/bin/python api_server.py
Restart=on-failure
RestartSec=10
StandardOutput=append:/var/log/aiframe/api.log
StandardError=append:/var/log/aiframe/api-error.log

[Install]
WantedBy=multi-user.target
```

#### WebXR Service Unit
```ini
# /etc/systemd/system/aiframe-webxr.service
[Unit]
Description=AI Frame WebXR HTTPS Server
After=network.target aiframe-api.service

[Service]
Type=simple
User=aiframe
Group=aiframe
WorkingDirectory=/opt/aiframe
ExecStart=/usr/bin/npx http-server -S -C certs/cert.pem -K certs/key.pem -p 8443 --cors
Restart=on-failure
RestartSec=10
StandardOutput=append:/var/log/aiframe/webxr.log
StandardError=append:/var/log/aiframe/webxr-error.log

[Install]
WantedBy=multi-user.target
```

#### Service Management Script
```bash
#!/bin/bash
# systemd-manage.sh - Systemd service management

case "$1" in
    install)
        # Copy service files
        sudo cp services/*.service /etc/systemd/system/
        
        # Reload systemd
        sudo systemctl daemon-reload
        
        # Enable services
        sudo systemctl enable aiframe-api
        sudo systemctl enable aiframe-webxr
        sudo systemctl enable aiframe-mobile
        
        echo "Services installed and enabled"
        ;;
    
    start)
        sudo systemctl start aiframe-api
        sudo systemctl start aiframe-webxr
        sudo systemctl start aiframe-mobile
        echo "Services started"
        ;;
    
    stop)
        sudo systemctl stop aiframe-api
        sudo systemctl stop aiframe-webxr
        sudo systemctl stop aiframe-mobile
        echo "Services stopped"
        ;;
    
    status)
        sudo systemctl status aiframe-api
        sudo systemctl status aiframe-webxr
        sudo systemctl status aiframe-mobile
        ;;
    
    logs)
        sudo journalctl -u aiframe-$2 -f
        ;;
    
    *)
        echo "Usage: $0 {install|start|stop|status|logs}"
        exit 1
        ;;
esac
```

## Health Monitoring

### Health Check Implementation
```python
# health_check.py
from fastapi import FastAPI
from typing import Dict, Any
import psutil
import aiofiles
import os
from datetime import datetime

app = FastAPI()

class HealthMonitor:
    def __init__(self):
        self.start_time = datetime.now()
    
    async def check_api_health(self) -> Dict[str, Any]:
        """Check API server health"""
        try:
            # Check basic responsiveness
            status = "healthy"
            
            # Check CPU usage
            cpu_percent = psutil.cpu_percent(interval=1)
            if cpu_percent > 80:
                status = "degraded"
            
            # Check memory usage
            memory = psutil.virtual_memory()
            if memory.percent > 90:
                status = "degraded"
            
            # Check disk usage
            disk = psutil.disk_usage('/')
            if disk.percent > 90:
                status = "degraded"
            
            return {
                "service": "api",
                "status": status,
                "uptime": (datetime.now() - self.start_time).total_seconds(),
                "metrics": {
                    "cpu_percent": cpu_percent,
                    "memory_percent": memory.percent,
                    "disk_percent": disk.percent
                }
            }
        except Exception as e:
            return {
                "service": "api",
                "status": "unhealthy",
                "error": str(e)
            }
    
    async def check_storage_health(self) -> Dict[str, Any]:
        """Check storage system health"""
        try:
            # Check if storage directories exist
            dirs_ok = all(
                os.path.exists(path) 
                for path in ['./uploads', './sessions']
            )
            
            # Check write permissions
            test_file = './uploads/.health_check'
            try:
                async with aiofiles.open(test_file, 'w') as f:
                    await f.write(str(datetime.now()))
                os.remove(test_file)
                write_ok = True
            except:
                write_ok = False
            
            return {
                "service": "storage",
                "status": "healthy" if dirs_ok and write_ok else "unhealthy",
                "directories_exist": dirs_ok,
                "write_permission": write_ok
            }
        except Exception as e:
            return {
                "service": "storage",
                "status": "unhealthy",
                "error": str(e)
            }
    
    async def check_dependencies(self) -> Dict[str, Any]:
        """Check external dependencies"""
        dependencies = {}
        
        # Check Redis if configured
        try:
            import redis
            r = redis.Redis(host='localhost', port=6379)
            r.ping()
            dependencies['redis'] = 'connected'
        except:
            dependencies['redis'] = 'disconnected'
        
        # Check database if configured
        try:
            # Database check logic here
            dependencies['database'] = 'connected'
        except:
            dependencies['database'] = 'disconnected'
        
        return {
            "service": "dependencies",
            "status": "healthy" if all(v == 'connected' for v in dependencies.values()) else "degraded",
            "connections": dependencies
        }

health_monitor = HealthMonitor()

@app.get("/health")
async def health_check():
    """Comprehensive health check endpoint"""
    api_health = await health_monitor.check_api_health()
    storage_health = await health_monitor.check_storage_health()
    deps_health = await health_monitor.check_dependencies()
    
    # Determine overall health
    all_statuses = [
        api_health['status'],
        storage_health['status'],
        deps_health['status']
    ]
    
    if any(s == 'unhealthy' for s in all_statuses):
        overall_status = 'unhealthy'
    elif any(s == 'degraded' for s in all_statuses):
        overall_status = 'degraded'
    else:
        overall_status = 'healthy'
    
    return {
        "status": overall_status,
        "timestamp": datetime.now().isoformat(),
        "services": {
            "api": api_health,
            "storage": storage_health,
            "dependencies": deps_health
        }
    }

@app.get("/health/live")
async def liveness_probe():
    """Simple liveness probe for orchestrators"""
    return {"status": "alive"}

@app.get("/health/ready")
async def readiness_probe():
    """Readiness probe for orchestrators"""
    # Check if service is ready to accept traffic
    storage_health = await health_monitor.check_storage_health()
    
    if storage_health['status'] == 'healthy':
        return {"status": "ready"}
    else:
        return {"status": "not_ready"}, 503
```

## Log Management

### Centralized Logging
```bash
#!/bin/bash
# log-aggregator.sh - Aggregate logs from all services

LOG_DIR="./logs"
AGGREGATE_LOG="$LOG_DIR/aggregate.log"

# Create log directory
mkdir -p $LOG_DIR

# Function to tail and tag logs
tail_with_tag() {
    local file=$1
    local tag=$2
    
    tail -F "$file" 2>/dev/null | while read line; do
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$tag] $line"
    done
}

# Start tailing all logs
tail_with_tag "logs/api.log" "API" >> $AGGREGATE_LOG &
tail_with_tag "logs/webxr.log" "WEBXR" >> $AGGREGATE_LOG &
tail_with_tag "logs/mobile.log" "MOBILE" >> $AGGREGATE_LOG &

# Also output to console
tail -F $AGGREGATE_LOG

# Cleanup on exit
trap "kill $(jobs -p)" EXIT

wait
```

### Log Rotation Configuration
```bash
# /etc/logrotate.d/aiframe
/var/log/aiframe/*.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 644 aiframe aiframe
    sharedscripts
    postrotate
        systemctl reload aiframe-api 2>/dev/null || true
    endscript
}
```

## Deployment Automation

### Deployment Script
```bash
#!/bin/bash
# deploy.sh - Automated deployment script

set -e

# Configuration
DEPLOY_USER="aiframe"
DEPLOY_HOST="production.example.com"
DEPLOY_PATH="/opt/aiframe"
BACKUP_PATH="/backups/aiframe"

# Functions
deploy_production() {
    echo "Deploying to production..."
    
    # Create backup
    ssh $DEPLOY_USER@$DEPLOY_HOST "
        mkdir -p $BACKUP_PATH
        tar -czf $BACKUP_PATH/backup-\$(date +%Y%m%d-%H%M%S).tar.gz $DEPLOY_PATH
    "
    
    # Copy files
    rsync -avz --exclude 'node_modules' --exclude '__pycache__' \
        --exclude 'venv' --exclude 'logs' \
        ./ $DEPLOY_USER@$DEPLOY_HOST:$DEPLOY_PATH/
    
    # Install dependencies and restart
    ssh $DEPLOY_USER@$DEPLOY_HOST "
        cd $DEPLOY_PATH
        
        # Python dependencies
        cd server
        source venv/bin/activate
        pip install -r requirements.txt
        
        # Node dependencies
        cd ..
        npm ci --production
        
        # Restart services
        sudo systemctl restart aiframe-api
        sudo systemctl restart aiframe-webxr
        sudo systemctl restart aiframe-mobile
        
        # Check status
        sleep 5
        systemctl status aiframe-api --no-pager
    "
    
    echo "Deployment complete!"
}

# Main
case "$1" in
    production)
        deploy_production
        ;;
    staging)
        deploy_staging
        ;;
    rollback)
        rollback_deployment
        ;;
    *)
        echo "Usage: $0 {production|staging|rollback}"
        exit 1
        ;;
esac
```

## Best Practices

### Service Management Guidelines
1. **Use process managers** for production (systemd, PM2)
2. **Implement health checks** for all services
3. **Centralize logging** for easier debugging
4. **Monitor resource usage** continuously
5. **Automate deployment** with scripts
6. **Use environment variables** for configuration
7. **Implement graceful shutdown** handlers
8. **Set up automatic restarts** on failure
9. **Use load balancing** for high availability
10. **Regular backups** before deployments

### Development vs Production
- **Development**: tmux for visibility and control
- **Staging**: Docker Compose for consistency
- **Production**: Systemd/PM2 for reliability

### Monitoring Checklist
- Service availability
- Resource utilization
- Error rates
- Response times
- Connection counts
- Log aggregation
- Alerting thresholds

## Troubleshooting

### Common Issues

#### Service Won't Start
```bash
# Check port availability
lsof -i :3001
netstat -tlnp | grep 3001

# Check permissions
ls -la /opt/aiframe
chmod +x scripts/*.sh

# Check dependencies
python3 --version
node --version
```

#### High Resource Usage
```bash
# Find resource-hungry processes
top -c
htop

# Check specific service
ps aux | grep api_server
pmap -x <PID>

# Restart service
systemctl restart aiframe-api
```

#### Connection Issues
```bash
# Test connectivity
curl http://localhost:3001/health
curl -k https://localhost:8443

# Check firewall
sudo ufw status
sudo iptables -L

# Check CORS headers
curl -I -X OPTIONS http://localhost:3001
```

## References
- [tmux Documentation](https://github.com/tmux/tmux/wiki)
- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [PM2 Documentation](https://pm2.keymetrics.io/)
- [Systemd Documentation](https://www.freedesktop.org/software/systemd/man/)