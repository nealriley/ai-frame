/**
 * Main Application Controller
 * Initializes and coordinates all modules
 */

class AIFrameApp {
    constructor() {
        this.initialized = false;
        this.setupEventListeners();
    }

    async initialize() {
        console.log('AI Frame initializing...');
        
        // Check WebXR support
        const xrSupported = await window.xrControls.checkXRSupport();
        
        // Update UI based on support
        const enterVRButton = document.getElementById('enter-vr');
        if (!xrSupported) {
            enterVRButton.textContent = 'WebXR Not Supported';
            enterVRButton.disabled = true;
        }
        
        // Initialize configuration UI
        this.setupConfigUI();
        
        // Setup capture status listener
        this.setupStatusListeners();
        
        // Check if already configured
        this.updateAPIStatus();
        
        this.initialized = true;
        console.log('AI Frame ready');
    }

    setupEventListeners() {
        // Wait for DOM to be ready
        if (document.readyState === 'loading') {
            document.addEventListener('DOMContentLoaded', () => this.initialize());
        } else {
            this.initialize();
        }
        
        // Handle page visibility changes
        document.addEventListener('visibilitychange', () => {
            if (document.hidden && window.mediaCapture.isRecording) {
                window.mediaCapture.stopRecording();
            }
        });
    }

    setupConfigUI() {
        const configBtn = document.getElementById('config-btn');
        const configPanel = document.getElementById('config-panel');
        const saveBtn = document.getElementById('save-config');
        const apiEndpointInput = document.getElementById('api-endpoint');
        const apiKeyInput = document.getElementById('api-key');
        
        // Toggle config panel
        configBtn.addEventListener('click', () => {
            configPanel.classList.toggle('hidden');
            
            // Load current config
            apiEndpointInput.value = window.configManager.getApiEndpoint() || '';
            apiKeyInput.value = window.configManager.getApiKey() || '';
        });
        
        // Save configuration
        saveBtn.addEventListener('click', () => {
            const endpoint = apiEndpointInput.value.trim();
            const apiKey = apiKeyInput.value.trim();
            
            if (!endpoint) {
                alert('Please enter an API endpoint URL');
                return;
            }
            
            // Validate URL
            try {
                new URL(endpoint);
            } catch (e) {
                alert('Please enter a valid URL');
                return;
            }
            
            // Save config
            window.configManager.setApiEndpoint(endpoint);
            window.configManager.setApiKey(apiKey);
            
            // Update UI
            configPanel.classList.add('hidden');
            this.updateAPIStatus();
            
            // Start polling if configured
            if (window.configManager.config.polling.enabled) {
                window.apiGateway.startPolling();
            }
        });
        
        // Enter VR button
        const enterVRBtn = document.getElementById('enter-vr');
        enterVRBtn.addEventListener('click', () => {
            const scene = document.querySelector('a-scene');
            if (scene) {
                scene.enterVR();
            }
        });
    }

    setupStatusListeners() {
        // Capture status updates
        window.addEventListener('capture-status', (event) => {
            const { message, isRecording } = event.detail;
            console.log('Capture status:', message);
            
            // Update UI if recording
            if (isRecording) {
                document.body.classList.add('recording');
            } else {
                document.body.classList.remove('recording');
            }
        });
        
        // API status updates
        window.addEventListener('api-status', (event) => {
            const { message } = event.detail;
            console.log('API status:', message);
            
            // Show temporary notification
            this.showNotification(message);
        });
        
        // Config changes
        window.addEventListener('config-changed', (event) => {
            this.updateAPIStatus();
        });
    }

    updateAPIStatus() {
        const statusElement = document.getElementById('api-status');
        const isConfigured = window.configManager.isConfigured();
        
        if (statusElement) {
            statusElement.textContent = isConfigured ? 
                'API: Configured' : 'API: Not configured';
            
            if (isConfigured) {
                statusElement.classList.add('configured');
            } else {
                statusElement.classList.remove('configured');
            }
        }
    }

    showNotification(message) {
        // Create notification element
        const notification = document.createElement('div');
        notification.className = 'notification';
        notification.textContent = message;
        notification.style.cssText = `
            position: fixed;
            top: 20px;
            right: 20px;
            background: rgba(102, 126, 234, 0.9);
            color: white;
            padding: 15px 20px;
            border-radius: 8px;
            z-index: 1000;
            animation: slideIn 0.3s ease;
        `;
        
        document.body.appendChild(notification);
        
        // Remove after 3 seconds
        setTimeout(() => {
            notification.style.animation = 'slideOut 0.3s ease';
            setTimeout(() => notification.remove(), 300);
        }, 3000);
    }

    // Public methods for global access
    async uploadCaptures() {
        const result = await window.apiGateway.batchUpload();
        if (result) {
            this.showNotification('Upload successful!');
        }
        return result;
    }

    startPolling() {
        window.apiGateway.startPolling();
    }

    stopPolling() {
        window.apiGateway.stopPolling();
    }
}

// Add CSS animations
const style = document.createElement('style');
style.textContent = `
    @keyframes slideIn {
        from {
            transform: translateX(100%);
            opacity: 0;
        }
        to {
            transform: translateX(0);
            opacity: 1;
        }
    }
    
    @keyframes slideOut {
        from {
            transform: translateX(0);
            opacity: 1;
        }
        to {
            transform: translateX(100%);
            opacity: 0;
        }
    }
    
    .notification {
        font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
    }
`;
document.head.appendChild(style);

// Initialize app
window.aiFrameApp = new AIFrameApp();

// Global helper functions
window.uploadAll = () => window.aiFrameApp.uploadCaptures();
window.startPolling = () => window.aiFrameApp.startPolling();
window.stopPolling = () => window.aiFrameApp.stopPolling();