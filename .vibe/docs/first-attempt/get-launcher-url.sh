#!/bin/bash

# AI Frame - Get Quest Launcher URL
# Automatically detects GitHub Codespaces URL and generates Meta Quest launcher link

set -e

echo "========================================="
echo "AI Frame - Quest Launcher URL Generator"
echo "========================================="
echo ""

# Detect if we're in GitHub Codespaces
if [ -n "$CODESPACE_NAME" ]; then
    echo "✅ GitHub Codespaces detected!"
    echo "  Codespace: $CODESPACE_NAME"
    echo "  Region: ${GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN:-app.github.dev}"
    echo ""
    
    # Construct the Codespaces URL for port 8443
    CODESPACE_URL="https://${CODESPACE_NAME}-8443.${GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN:-app.github.dev}"
    
    echo "📍 Your Codespace URL:"
    echo "  $CODESPACE_URL"
    echo ""
    
    # URL encode the Codespace URL
    ENCODED_URL=$(python3 -c "import urllib.parse; print(urllib.parse.quote('${CODESPACE_URL}/', safe=''))")
    
    # Create the Meta Quest launcher URL
    LAUNCHER_URL="https://www.oculus.com/open_url/?url=${ENCODED_URL}"
    
    echo "🎭 Meta Quest Launcher URL:"
    echo "  $LAUNCHER_URL"
    echo ""
    echo "📱 QR Launcher Page:"
    echo "  ${CODESPACE_URL}/qr-launcher.html"
    echo ""
    echo "To use on Quest:"
    echo "  1. Open the QR Scanner app on your Quest"
    echo "  2. Scan a QR code containing the launcher URL above"
    echo "  3. Or visit the QR launcher page to generate one"
    echo ""
    
    # Save to file for easy access
    echo "$LAUNCHER_URL" > launcher-url.txt
    echo "💾 Launcher URL saved to: launcher-url.txt"
    
else
    echo "⚠️  Not running in GitHub Codespaces"
    echo ""
    
    # Try to detect local IP
    LOCAL_IP=$(hostname -I | awk '{print $1}' 2>/dev/null || echo "localhost")
    
    echo "📍 Local URLs:"
    echo "  WebXR: https://${LOCAL_IP}:8443"
    echo "  Mobile: http://${LOCAL_IP}:8080/mobile.html"
    echo "  API: http://${LOCAL_IP}:3001"
    echo ""
    
    # Create launcher URL for local IP
    LOCAL_URL="https://${LOCAL_IP}:8443"
    ENCODED_URL=$(python3 -c "import urllib.parse; print(urllib.parse.quote('${LOCAL_URL}/', safe=''))")
    LAUNCHER_URL="https://www.oculus.com/open_url/?url=${ENCODED_URL}"
    
    echo "🎭 Meta Quest Launcher URL (local network):"
    echo "  $LAUNCHER_URL"
    echo ""
    echo "Note: Quest must be on same network for local access"
fi

echo ""
echo "========================================="