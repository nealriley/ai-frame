#!/bin/bash

# Monitor all services in real-time
echo "=== AI Frame Service Monitor ==="
echo "Watching logs from all services..."
echo "Press Ctrl+C to stop monitoring"
echo ""

while true; do
    clear
    echo "=== AI Frame Service Monitor - $(date) ==="
    echo ""
    
    echo "📡 API Server (Port 3001):"
    echo "─────────────────────────"
    tmux capture-pane -t server:0.0 -p | tail -10
    echo ""
    
    echo "🌐 WebXR HTTPS Server (Port 8443):"
    echo "──────────────────────────────────"
    tmux capture-pane -t server:0.1 -p | tail -5
    echo ""
    
    echo "📱 Portal HTTP Server (Port 8080):"
    echo "──────────────────────────────────"
    tmux capture-pane -t server:0.2 -p | tail -5
    echo ""
    
    sleep 2
done