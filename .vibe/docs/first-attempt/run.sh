#!/bin/bash

echo "AI Frame - Starting Services"
echo "============================"
echo ""
echo "Choose an option:"
echo "1) Serve with HTTPS (recommended for WebXR)"
echo "2) Serve with HTTP (development only)"
echo "3) Start example API server"
echo "4) Start both HTTPS server and API"
echo ""
read -p "Enter choice [1-4]: " choice

case $choice in
    1)
        echo "Starting HTTPS server on https://localhost:8443"
        npm run serve:https
        ;;
    2)
        echo "Starting HTTP server on http://localhost:8080"
        npm run serve
        ;;
    3)
        echo "Starting example API server..."
        node example-server.js
        ;;
    4)
        echo "Starting both servers..."
        node example-server.js &
        API_PID=$!
        echo "API server PID: $API_PID"
        npm run serve:https
        kill $API_PID 2>/dev/null
        ;;
    *)
        echo "Invalid choice"
        exit 1
        ;;
esac
