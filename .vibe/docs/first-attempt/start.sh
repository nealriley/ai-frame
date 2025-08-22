#!/bin/bash

# AI Frame - Complete Startup Script
# Starts all services and displays launcher URLs

set -e

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                  AI FRAME - STARTUP                         ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# Get launcher URLs first
echo "🔍 Detecting environment..."
./get-launcher-url.sh
echo ""

# Start services
echo "🚀 Starting all services..."
echo ""

# Check if services are already running
if tmux has-session -t aiframe 2>/dev/null; then
    echo "⚠️  Services already running in tmux session 'aiframe'"
    echo "   Run './run-services.sh' and choose option 4 to stop them first"
else
    # Start services in tmux
    echo "2" | ./run-services.sh > /dev/null 2>&1
    echo "✅ Services started in tmux session 'aiframe'"
fi

echo ""
echo "⏳ Waiting for services to be ready..."
sleep 5

# Check service status
echo ""
echo "📊 Service Status:"
echo "──────────────────"

# Check API Server
if curl -s http://localhost:3001/ > /dev/null 2>&1; then
    echo "✅ API Server:     http://localhost:3001"
else
    echo "❌ API Server:     Not responding"
fi

# Check WebXR Server
if curl -sk https://localhost:8443/ > /dev/null 2>&1; then
    echo "✅ WebXR Server:   https://localhost:8443"
else
    echo "⚠️  WebXR Server:   Starting... (certificate warning is normal)"
fi

# Check Mobile Server
if curl -s http://localhost:8080/ > /dev/null 2>&1; then
    echo "✅ Mobile Server:  http://localhost:8080/mobile.html"
else
    echo "⚠️  Mobile Server:  Starting..."
fi

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                    QUICK ACCESS URLS                        ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# Display launcher URL if saved
if [ -f "launcher-url.txt" ]; then
    LAUNCHER_URL=$(cat launcher-url.txt)
    echo "🎭 Quest Launcher URL:"
    echo "   $LAUNCHER_URL"
    echo ""
fi

# Get Codespace URL if available
if [ -n "$CODESPACE_NAME" ]; then
    CODESPACE_URL="https://${CODESPACE_NAME}-8443.${GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN:-app.github.dev}"
    echo "📱 Direct Access URLs:"
    echo "   WebXR:  $CODESPACE_URL"
    echo "   Mobile: https://${CODESPACE_NAME}-8080.${GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN:-app.github.dev}/mobile.html"
    echo "   QR Gen: $CODESPACE_URL/qr-launcher.html"
else
    LOCAL_IP=$(hostname -I | awk '{print $1}' 2>/dev/null || echo "localhost")
    echo "📱 Local Network URLs:"
    echo "   WebXR:  https://$LOCAL_IP:8443"
    echo "   Mobile: http://$LOCAL_IP:8080/mobile.html"
    echo "   API:    http://$LOCAL_IP:3001"
fi

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                        COMMANDS                             ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "📺 View services:      tmux attach -t aiframe"
echo "🔄 Restart services:   ./run-services.sh (option 4, then 2)"
echo "📊 API Documentation:  http://localhost:3001/docs"
echo "🛑 Stop all:          tmux kill-session -t aiframe"
echo ""
echo "✨ AI Frame is ready! Open the URLs above to start capturing."
echo ""