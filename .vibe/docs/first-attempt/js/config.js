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
