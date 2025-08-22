#!/bin/bash

# Extract Codespaces environment variables
CODESPACE_NAME="${CODESPACE_NAME}"
DOMAIN="${GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN}"

if [ -z "$CODESPACE_NAME" ] || [ -z "$DOMAIN" ]; then
    echo "Not running in GitHub Codespaces, using localhost URLs"
    API_URL="http://localhost:3001"
    WEBXR_URL="https://localhost:8443"
    PORTAL_URL="http://localhost:8080"
else
    echo "Detected GitHub Codespaces environment"
    echo "Codespace: $CODESPACE_NAME"
    echo "Domain: $DOMAIN"
    
    # Construct public URLs
    API_URL="https://${CODESPACE_NAME}-3001.${DOMAIN}"
    WEBXR_URL="https://${CODESPACE_NAME}-8443.${DOMAIN}"
    PORTAL_URL="https://${CODESPACE_NAME}-8080.${DOMAIN}"
fi

echo ""
echo "Service URLs:"
echo "  API Server: $API_URL"
echo "  WebXR App: $WEBXR_URL"
echo "  Portal: $PORTAL_URL"
echo ""

# Update config.json with correct URLs
cat > /workspaces/ai-frame/config/config.json << EOF
{
  "api_endpoints": {
    "local": "${API_URL}",
    "webxr": "${WEBXR_URL}",
    "portal": "${PORTAL_URL}"
  },
  "settings": {
    "storage_days": 7,
    "max_file_size_mb": 100,
    "enable_ai_processing": false,
    "auto_cleanup": true
  },
  "media_types": {
    "image": ["jpg", "jpeg", "png", "gif", "webp"],
    "video": ["mp4", "webm", "mov"],
    "audio": ["mp3", "wav", "webm"],
    "text": ["txt", "json", "md"]
  },
  "codespaces": {
    "name": "${CODESPACE_NAME}",
    "domain": "${DOMAIN}",
    "ports": {
      "api": 3001,
      "webxr": 8443,
      "portal": 8080
    }
  },
  "public_urls": {
    "api": "${API_URL}",
    "webxr": "${WEBXR_URL}",
    "portal": "${PORTAL_URL}",
    "quest_launcher": "https://www.oculus.com/open_url/?url=${WEBXR_URL}"
  }
}
EOF

echo "Configuration updated!"

# Update JavaScript configuration to use the correct API endpoint
cat > /workspaces/ai-frame/js/config.js << 'EOJS'
/**
 * Configuration Management Module
 * Handles API endpoints and settings for AI Frame
 */

class ConfigManager {
    constructor() {
        this.config = null;
        this.loadConfig();
    }

    async loadConfig() {
        try {
            const response = await fetch('/config/config.json');
            this.config = await response.json();
            console.log('Configuration loaded:', this.config);
        } catch (error) {
            console.warn('Could not load config.json, using defaults');
            this.setDefaultConfig();
        }
    }

    setDefaultConfig() {
        // Use Codespaces URLs if available
        const codespace = this.detectCodespace();
        
        if (codespace) {
            const base = `https://${codespace.name}-{port}.${codespace.domain}`;
            this.config = {
                api_endpoints: {
                    local: base.replace('{port}', '3001'),
                    webxr: base.replace('{port}', '8443'),
                    portal: base.replace('{port}', '8080')
                }
            };
        } else {
            this.config = {
                api_endpoints: {
                    local: 'http://localhost:3001',
                    webxr: 'https://localhost:8443',
                    portal: 'http://localhost:8080'
                }
            };
        }
    }

    detectCodespace() {
        // Check if we're in a Codespaces environment
        const hostname = window.location.hostname;
        const match = hostname.match(/^([^-]+(-[^-]+)*)-\d+\.(.+)$/);
        
        if (match) {
            return {
                name: match[1],
                domain: match[3]
            };
        }
        
        return null;
    }

    getApiEndpoint() {
        if (!this.config) {
            this.setDefaultConfig();
        }
        
        // Always use the configured API endpoint
        const endpoint = this.config.api_endpoints.local + '/upload';
        console.log('Using API endpoint:', endpoint);
        return endpoint;
    }

    getHeaders() {
        return {
            // Add any authentication headers if needed
        };
    }

    getSetting(key) {
        return this.config?.settings?.[key];
    }
}

// Initialize global config manager
window.configManager = new ConfigManager();
EOJS

echo "JavaScript configuration updated!"

# Update the portal.html to use dynamic API URL
sed -i "s|const API_BASE = 'http://localhost:3001'|const API_BASE = '${API_URL}'|g" /workspaces/ai-frame/portal.html

echo "Portal HTML updated with API URL: ${API_URL}"
echo ""
echo "Setup complete! Services are configured for GitHub Codespaces."
echo ""
echo "To access your services:"
echo "  - Portal: ${PORTAL_URL}/portal.html"
echo "  - WebXR App: ${WEBXR_URL}"
echo "  - API Docs: ${API_URL}/docs"
echo ""
echo "For Meta Quest access:"
echo "  1. Make sure ports are set to PUBLIC in Codespaces"
echo "  2. Use: ${WEBXR_URL}"