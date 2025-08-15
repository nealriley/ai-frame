/**
 * WebXR Controls Module
 * Handles VR/AR session management and interactions
 */

class XRControls {
    constructor() {
        this.xrSession = null;
        this.isImmersive = false;
        this.hudVisible = false;
        this.initializeComponents();
    }

    initializeComponents() {
        // Register custom A-Frame component for XR capture
        AFRAME.registerComponent('xr-capture', {
            init: function() {
                const scene = this.el;
                
                // Initialize capture on scene load
                scene.addEventListener('loaded', () => {
                    window.xrControls.setupXRCapture();
                });
                
                // Handle enter VR
                scene.addEventListener('enter-vr', () => {
                    window.xrControls.onEnterVR();
                });
                
                // Handle exit VR
                scene.addEventListener('exit-vr', () => {
                    window.xrControls.onExitVR();
                });
            }
        });

        // Register gesture handler component
        AFRAME.registerComponent('gesture-handler', {
            init: function() {
                this.el.addEventListener('thumbsup', () => {
                    window.xrControls.toggleHUD();
                });
                
                this.el.addEventListener('pinch', () => {
                    window.mediaCapture.captureCanvas();
                });
            }
        });
    }

    async checkXRSupport() {
        if ('xr' in navigator) {
            try {
                const vrSupported = await navigator.xr.isSessionSupported('immersive-vr');
                const arSupported = await navigator.xr.isSessionSupported('immersive-ar');
                
                const status = vrSupported ? 'VR Ready' : 
                              arSupported ? 'AR Ready' : 
                              'WebXR Not Supported';
                
                this.updateXRStatus(status, vrSupported || arSupported);
                return vrSupported || arSupported;
            } catch (error) {
                console.error('Error checking XR support:', error);
            }
        }
        
        this.updateXRStatus('WebXR Not Available', false);
        return false;
    }

    setupXRCapture() {
        // Setup capture button interactions
        const captureButtons = document.querySelectorAll('.capture-btn');
        
        captureButtons.forEach(button => {
            button.addEventListener('click', (event) => {
                const buttonId = event.target.id;
                this.handleCaptureButton(buttonId);
            });
        });
        
        // Setup hand tracking interactions if available
        this.setupHandTracking();
    }

    setupHandTracking() {
        const leftHand = document.getElementById('left-hand');
        const rightHand = document.getElementById('right-hand');
        
        if (leftHand) {
            leftHand.addEventListener('pinchstarted', () => {
                this.handleGesture('pinch', 'left');
            });
            
            leftHand.addEventListener('pinchended', () => {
                this.handleGesture('pinch-end', 'left');
            });
        }
        
        if (rightHand) {
            rightHand.addEventListener('thumbsup', () => {
                this.toggleHUD();
            });
        }
    }

    handleCaptureButton(buttonId) {
        switch(buttonId) {
            case 'capture-video-btn':
                this.captureVideo();
                break;
            case 'capture-canvas-btn':
                this.captureFrame();
                break;
            case 'capture-audio-btn':
                this.captureAudio();
                break;
            case 'capture-text-btn':
                this.showVirtualKeyboard();
                break;
        }
    }

    async captureVideo() {
        const button = document.getElementById('capture-video-btn');
        button.setAttribute('color', '#ff6666');
        button.setAttribute('animation', 'property: scale; to: 1.1 1.1 1.1; dur: 200');
        
        await window.mediaCapture.captureVideo();
        
        button.setAttribute('color', '#ff3333');
        button.removeAttribute('animation');
    }

    async captureAudio() {
        const button = document.getElementById('capture-audio-btn');
        button.setAttribute('color', '#6666ff');
        button.setAttribute('animation', 'property: scale; to: 1.1 1.1 1.1; dur: 200');
        
        await window.mediaCapture.captureAudio();
        
        button.setAttribute('color', '#3333ff');
        button.removeAttribute('animation');
    }

    async captureFrame() {
        const button = document.getElementById('capture-canvas-btn');
        button.setAttribute('color', '#66ff66');
        button.setAttribute('animation', 'property: scale; to: 1.1 1.1 1.1; dur: 200');
        
        await window.mediaCapture.captureCanvas();
        
        setTimeout(() => {
            button.setAttribute('color', '#33ff33');
            button.removeAttribute('animation');
        }, 200);
    }

    showVirtualKeyboard() {
        const keyboard = document.getElementById('virtual-keyboard');
        keyboard.setAttribute('visible', true);
        
        // Create simple virtual keyboard if not exists
        if (!keyboard.hasChildNodes()) {
            this.createVirtualKeyboard(keyboard);
        }
    }

    createVirtualKeyboard(container) {
        const keys = [
            'QWERTYUIOP',
            'ASDFGHJKL',
            'ZXCVBNM'
        ];
        
        let yOffset = 0.2;
        keys.forEach((row, rowIndex) => {
            let xOffset = -(row.length * 0.06) / 2;
            
            for (let char of row) {
                const key = document.createElement('a-box');
                key.setAttribute('position', `${xOffset} ${yOffset} 0`);
                key.setAttribute('width', '0.05');
                key.setAttribute('height', '0.05');
                key.setAttribute('depth', '0.02');
                key.setAttribute('color', '#333');
                key.setAttribute('text', `value: ${char}; align: center; width: 0.3`);
                key.setAttribute('class', 'keyboard-key');
                key.addEventListener('click', () => {
                    this.handleKeyPress(char);
                });
                
                container.appendChild(key);
                xOffset += 0.06;
            }
            yOffset -= 0.06;
        }
        
        // Add space bar
        const spacebar = document.createElement('a-box');
        spacebar.setAttribute('position', `0 ${yOffset - 0.06} 0`);
        spacebar.setAttribute('width', '0.3');
        spacebar.setAttribute('height', '0.05');
        spacebar.setAttribute('depth', '0.02');
        spacebar.setAttribute('color', '#333');
        spacebar.setAttribute('text', 'value: SPACE; align: center; width: 1');
        spacebar.addEventListener('click', () => {
            this.handleKeyPress(' ');
        });
        container.appendChild(spacebar);
        
        // Add enter key
        const enterKey = document.createElement('a-box');
        enterKey.setAttribute('position', `0.2 ${yOffset - 0.06} 0`);
        enterKey.setAttribute('width', '0.1');
        enterKey.setAttribute('height', '0.05');
        enterKey.setAttribute('depth', '0.02');
        enterKey.setAttribute('color', '#0a0');
        enterKey.setAttribute('text', 'value: ENTER; align: center; width: 0.5');
        enterKey.addEventListener('click', () => {
            this.submitText();
        });
        container.appendChild(enterKey);
    }

    handleKeyPress(char) {
        this.currentText = (this.currentText || '') + char;
        this.updateTextDisplay();
    }

    submitText() {
        if (this.currentText) {
            window.mediaCapture.captureText(this.currentText);
            this.currentText = '';
            this.updateTextDisplay();
            
            // Hide keyboard
            const keyboard = document.getElementById('virtual-keyboard');
            keyboard.setAttribute('visible', false);
        }
    }

    updateTextDisplay() {
        const statusText = document.getElementById('status-text');
        if (statusText) {
            statusText.setAttribute('value', `Text: ${this.currentText || '(empty)'}`);
        }
    }

    toggleHUD() {
        this.hudVisible = !this.hudVisible;
        const hudPanel = document.getElementById('hud-panel');
        if (hudPanel) {
            hudPanel.setAttribute('visible', this.hudVisible);
        }
    }

    onEnterVR() {
        this.isImmersive = true;
        document.getElementById('control-panel').classList.add('hidden-in-vr');
        
        // Show HUD
        this.hudVisible = true;
        const hudPanel = document.getElementById('hud-panel');
        if (hudPanel) {
            hudPanel.setAttribute('visible', true);
        }
        
        // Initialize media streams
        window.mediaCapture.initializeStreams();
    }

    onExitVR() {
        this.isImmersive = false;
        document.getElementById('control-panel').classList.remove('hidden-in-vr');
        
        // Hide HUD
        this.hudVisible = false;
        const hudPanel = document.getElementById('hud-panel');
        if (hudPanel) {
            hudPanel.setAttribute('visible', false);
        }
    }

    handleGesture(gesture, hand) {
        console.log(`Gesture detected: ${gesture} on ${hand} hand`);
        
        switch(gesture) {
            case 'pinch':
                window.mediaCapture.captureCanvas();
                break;
            case 'thumbsup':
                this.toggleHUD();
                break;
        }
    }

    updateXRStatus(status, ready) {
        const statusElement = document.getElementById('xr-status');
        if (statusElement) {
            statusElement.textContent = `WebXR: ${status}`;
            if (ready) {
                statusElement.classList.add('ready');
            }
        }
    }
}

// Global XR controls instance
window.xrControls = new XRControls();