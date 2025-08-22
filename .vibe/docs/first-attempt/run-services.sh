#!/bin/bash

# AI Frame Multi-Service Runner
# Starts all services in separate tmux panes or Docker containers

set -e

echo "========================================="
echo "AI Frame - Multi-Service Launcher"
echo "========================================="
echo ""
echo "Choose deployment method:"
echo "1) Docker Compose (recommended for production)"
echo "2) Tmux sessions (recommended for development)"
echo "3) Individual terminals (manual control)"
echo "4) Stop all services"
echo ""
read -p "Enter choice [1-4]: " choice

# Get local IP for display
LOCAL_IP=$(hostname -I | awk '{print $1}')
if [ -z "$LOCAL_IP" ]; then
    LOCAL_IP="localhost"
fi

case $choice in
    1)
        echo "Starting services with Docker Compose..."
        
        # Check if Docker is installed
        if ! command -v docker &> /dev/null; then
            echo "❌ Docker is not installed"
            echo "Please install Docker first: https://docs.docker.com/get-docker/"
            exit 1
        fi
        
        # Generate certificates if needed
        if [ ! -f "certs/cert.pem" ]; then
            echo "Generating HTTPS certificates..."
            mkdir -p certs
            openssl req -x509 -newkey rsa:4096 \
                -keyout certs/key.pem \
                -out certs/cert.pem \
                -days 365 -nodes \
                -subj "/C=US/ST=State/L=City/O=AIFrame/CN=localhost"
        fi
        
        # Start services
        docker-compose up -d
        
        echo ""
        echo "✅ Services started with Docker Compose"
        echo ""
        echo "Access URLs:"
        echo "  WebXR (VR/AR):  https://$LOCAL_IP:8443"
        echo "  Mobile:         http://$LOCAL_IP:8080/mobile.html"
        echo "  API Server:     http://$LOCAL_IP:3001"
        echo "  QR Launcher:    https://$LOCAL_IP:8443/qr-launcher.html"
        echo ""
        echo "View logs: docker-compose logs -f"
        echo "Stop all:  docker-compose down"
        ;;
        
    2)
        echo "Starting services in tmux sessions..."
        
        # Check if tmux is installed
        if ! command -v tmux &> /dev/null; then
            echo "❌ tmux is not installed"
            echo "Installing tmux..."
            sudo apt-get update && sudo apt-get install -y tmux
        fi
        
        # Kill existing session if it exists
        tmux kill-session -t aiframe 2>/dev/null || true
        
        # Create new session with multiple panes
        tmux new-session -d -s aiframe -n services
        
        # Split window into 4 panes
        tmux split-window -h -t aiframe:services
        tmux split-window -v -t aiframe:services.0
        tmux split-window -v -t aiframe:services.1
        
        # Pane 0: Python API Server
        tmux send-keys -t aiframe:services.0 "cd $(pwd)/server" C-m
        tmux send-keys -t aiframe:services.0 "echo '🚀 Starting API Server on port 3001...'" C-m
        tmux send-keys -t aiframe:services.0 "pip install -r requirements.txt" C-m
        tmux send-keys -t aiframe:services.0 "python3 api_server.py" C-m
        
        # Pane 1: WebXR HTTPS Server
        tmux send-keys -t aiframe:services.1 "cd $(pwd)" C-m
        tmux send-keys -t aiframe:services.1 "echo '🌐 Starting WebXR HTTPS Server on port 8443...'" C-m
        
        # Generate certificates if needed
        if [ ! -f "certs/cert.pem" ]; then
            tmux send-keys -t aiframe:services.1 "mkdir -p certs && openssl req -x509 -newkey rsa:4096 -keyout certs/key.pem -out certs/cert.pem -days 365 -nodes -subj '/CN=localhost'" C-m
            sleep 2
        fi
        
        tmux send-keys -t aiframe:services.1 "npx http-server -S -C certs/cert.pem -K certs/key.pem -p 8443" C-m
        
        # Pane 2: Mobile HTTP Server
        tmux send-keys -t aiframe:services.2 "cd $(pwd)" C-m
        tmux send-keys -t aiframe:services.2 "echo '📱 Starting Mobile Server on port 8080...'" C-m
        tmux send-keys -t aiframe:services.2 "npx http-server -p 8080" C-m
        
        # Pane 3: Status monitoring
        tmux send-keys -t aiframe:services.3 "cd $(pwd)" C-m
        tmux send-keys -t aiframe:services.3 "echo '📊 Service Monitor'" C-m
        tmux send-keys -t aiframe:services.3 "echo ''" C-m
        tmux send-keys -t aiframe:services.3 "echo 'Services Status:'" C-m
        tmux send-keys -t aiframe:services.3 "echo '  API Server:  http://localhost:3001'" C-m
        tmux send-keys -t aiframe:services.3 "echo '  WebXR:       https://localhost:8443'" C-m
        tmux send-keys -t aiframe:services.3 "echo '  Mobile:      http://localhost:8080/mobile.html'" C-m
        tmux send-keys -t aiframe:services.3 "echo ''" C-m
        tmux send-keys -t aiframe:services.3 "echo 'Waiting for services to start...'" C-m
        sleep 3
        tmux send-keys -t aiframe:services.3 "watch -n 5 'echo \"=== API Server Status ===\"; curl -s http://localhost:3001/status | python3 -m json.tool | head -20'" C-m
        
        echo ""
        echo "✅ Services started in tmux session 'aiframe'"
        echo ""
        echo "Access URLs:"
        echo "  WebXR (VR/AR):  https://$LOCAL_IP:8443"
        echo "  Mobile:         http://$LOCAL_IP:8080/mobile.html"
        echo "  API Server:     http://$LOCAL_IP:3001"
        echo "  QR Launcher:    https://$LOCAL_IP:8443/qr-launcher.html"
        echo ""
        echo "Attach to session: tmux attach -t aiframe"
        echo "Detach: Ctrl+B, then D"
        echo "Stop all: tmux kill-session -t aiframe"
        ;;
        
    3)
        echo "Starting services individually..."
        echo ""
        echo "Please run these commands in separate terminals:"
        echo ""
        echo "Terminal 1 - API Server:"
        echo "  cd server"
        echo "  pip install -r requirements.txt"
        echo "  python3 api_server.py"
        echo ""
        echo "Terminal 2 - WebXR HTTPS Server:"
        
        if [ ! -f "certs/cert.pem" ]; then
            echo "  # Generate certificates first:"
            echo "  mkdir -p certs"
            echo "  openssl req -x509 -newkey rsa:4096 -keyout certs/key.pem -out certs/cert.pem -days 365 -nodes -subj '/CN=localhost'"
        fi
        
        echo "  npx http-server -S -C certs/cert.pem -K certs/key.pem -p 8443"
        echo ""
        echo "Terminal 3 - Mobile HTTP Server:"
        echo "  npx http-server -p 8080"
        echo ""
        echo "Access URLs:"
        echo "  WebXR (VR/AR):  https://$LOCAL_IP:8443"
        echo "  Mobile:         http://$LOCAL_IP:8080/mobile.html"
        echo "  API Server:     http://$LOCAL_IP:3001"
        echo "  QR Launcher:    https://$LOCAL_IP:8443/qr-launcher.html"
        ;;
        
    4)
        echo "Stopping all services..."
        
        # Stop Docker if running
        if command -v docker &> /dev/null; then
            docker-compose down 2>/dev/null || true
        fi
        
        # Stop tmux session
        tmux kill-session -t aiframe 2>/dev/null || true
        
        # Kill any remaining processes on our ports
        for port in 3001 8443 8080; do
            pid=$(lsof -ti:$port 2>/dev/null) || true
            if [ ! -z "$pid" ]; then
                echo "Stopping process on port $port (PID: $pid)"
                kill -9 $pid 2>/dev/null || true
            fi
        done
        
        echo "✅ All services stopped"
        ;;
        
    *)
        echo "Invalid choice"
        exit 1
        ;;
esac

echo ""
echo "========================================="