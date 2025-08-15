/**
 * API Gateway Module
 * Handles communication with the configured AI processing endpoint
 */

class APIGateway {
    constructor() {
        this.uploadQueue = [];
        this.isUploading = false;
        this.pollingInterval = null;
    }

    async uploadMedia(mediaData) {
        const endpoint = window.configManager.getApiEndpoint();
        
        if (!endpoint) {
            console.error('API endpoint not configured');
            this.showError('Please configure API endpoint first');
            return null;
        }

        try {
            const formData = new FormData();
            const timestamp = Date.now();
            
            // Add media files to form data
            if (mediaData.video) {
                formData.append('video', mediaData.video, `video_${timestamp}.webm`);
            }
            if (mediaData.audio) {
                formData.append('audio', mediaData.audio, `audio_${timestamp}.webm`);
            }
            if (mediaData.canvas) {
                formData.append('image', mediaData.canvas, `frame_${timestamp}.png`);
            }
            if (mediaData.text) {
                formData.append('text', mediaData.text);
            }
            
            // Add metadata
            formData.append('timestamp', timestamp.toString());
            formData.append('source', 'webxr');
            formData.append('device', navigator.userAgent);
            
            // Get headers including auth
            const headers = window.configManager.getHeaders();
            
            this.updateStatus('Uploading media...');
            
            const response = await fetch(endpoint, {
                method: 'POST',
                headers: headers,
                body: formData
            });

            if (!response.ok) {
                throw new Error(`Upload failed: ${response.status} ${response.statusText}`);
            }

            const result = await response.json();
            this.updateStatus('Upload successful');
            
            // Handle response - might contain AR objects to render
            if (result.objects) {
                this.processARObjects(result.objects);
            }
            
            return result;
        } catch (error) {
            console.error('Upload failed:', error);
            this.showError(`Upload failed: ${error.message}`);
            return null;
        }
    }

    async batchUpload() {
        const capturedData = window.mediaCapture.getCapturedData();
        
        // Check if there's any data to upload
        const hasData = capturedData.video || capturedData.audio || 
                       capturedData.canvas || capturedData.text;
        
        if (!hasData) {
            this.showError('No media captured to upload');
            return null;
        }
        
        const result = await this.uploadMedia(capturedData);
        
        if (result) {
            // Clear captured data after successful upload
            window.mediaCapture.clearCapturedData();
        }
        
        return result;
    }

    startPolling(interval = 5000) {
        if (this.pollingInterval) {
            return; // Already polling
        }
        
        const endpoint = window.configManager.getApiEndpoint();
        if (!endpoint) {
            console.error('Cannot start polling - API not configured');
            return;
        }
        
        this.pollingInterval = setInterval(async () => {
            await this.pollForObjects();
        }, interval);
        
        // Initial poll
        this.pollForObjects();
    }

    stopPolling() {
        if (this.pollingInterval) {
            clearInterval(this.pollingInterval);
            this.pollingInterval = null;
        }
    }

    async pollForObjects() {
        const endpoint = window.configManager.getApiEndpoint();
        if (!endpoint) return;
        
        try {
            const pollEndpoint = endpoint.replace('/upload', '/poll');
            const headers = window.configManager.getHeaders();
            
            const response = await fetch(pollEndpoint, {
                method: 'GET',
                headers: headers
            });
            
            if (!response.ok) {
                throw new Error(`Polling failed: ${response.status}`);
            }
            
            const data = await response.json();
            
            if (data.objects && data.objects.length > 0) {
                this.processARObjects(data.objects);
            }
        } catch (error) {
            console.error('Polling error:', error);
        }
    }

    processARObjects(objects) {
        // Process received AR objects and add them to the scene
        const container = document.getElementById('ar-objects-container');
        if (!container) return;
        
        objects.forEach(obj => {
            this.createARObject(obj, container);
        });
    }

    createARObject(objData, container) {
        // Create A-Frame entity based on object data
        const entity = document.createElement('a-entity');
        
        // Set position
        if (objData.position) {
            entity.setAttribute('position', objData.position);
        } else {
            // Random position in front of user
            const x = (Math.random() - 0.5) * 4;
            const y = Math.random() * 2 + 1;
            const z = -Math.random() * 3 - 2;
            entity.setAttribute('position', `${x} ${y} ${z}`);
        }
        
        // Set geometry based on type
        if (objData.type === 'image' && objData.url) {
            entity.setAttribute('geometry', 'primitive: plane; width: 1; height: 1');
            entity.setAttribute('material', `src: ${objData.url}`);
        } else if (objData.type === 'text') {
            entity.setAttribute('text', `value: ${objData.content}; align: center`);
        } else if (objData.type === 'model' && objData.url) {
            entity.setAttribute('gltf-model', objData.url);
        } else {
            // Default to a colored box
            entity.setAttribute('geometry', 'primitive: box');
            entity.setAttribute('material', `color: ${objData.color || '#4CC3D9'}`);
        }
        
        // Add interaction
        entity.setAttribute('class', 'ar-object');
        entity.setAttribute('animation__hover', 
            'property: scale; to: 1.2 1.2 1.2; startEvents: mouseenter; dur: 200');
        entity.setAttribute('animation__leave', 
            'property: scale; to: 1 1 1; startEvents: mouseleave; dur: 200');
        
        // Add metadata
        entity.dataset.objectId = objData.id || Date.now();
        entity.dataset.timestamp = objData.timestamp || Date.now();
        
        container.appendChild(entity);
    }

    updateStatus(message) {
        window.dispatchEvent(new CustomEvent('api-status', {
            detail: { message }
        }));
    }

    showError(message) {
        console.error(message);
        this.updateStatus(`Error: ${message}`);
    }
}

// Global API instance
window.apiGateway = new APIGateway();