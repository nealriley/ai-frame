/**
 * Media Capture Module
 * Handles video, audio, canvas capture and text input
 */

class MediaCapture {
    constructor() {
        this.videoStream = null;
        this.audioStream = null;
        this.mediaRecorder = null;
        this.isRecording = false;
        this.capturedData = {
            video: null,
            audio: null,
            canvas: null,
            text: ''
        };
    }

    async initializeStreams() {
        try {
            // Initialize video stream (camera)
            if (navigator.mediaDevices && navigator.mediaDevices.getUserMedia) {
                this.videoStream = await navigator.mediaDevices.getUserMedia({
                    video: { 
                        facingMode: 'environment',
                        width: { ideal: 1920 },
                        height: { ideal: 1080 }
                    }
                });
            }
        } catch (error) {
            console.error('Failed to initialize video stream:', error);
        }
    }

    async captureVideo(duration = 5000) {
        if (this.isRecording) {
            console.warn('Already recording');
            return null;
        }

        try {
            const stream = await navigator.mediaDevices.getUserMedia({
                video: { 
                    facingMode: 'environment',
                    width: { ideal: 1920 },
                    height: { ideal: 1080 }
                },
                audio: true
            });

            const chunks = [];
            const settings = window.configManager.getCaptureSettings('video');
            
            this.mediaRecorder = new MediaRecorder(stream, {
                mimeType: settings.mimeType || 'video/webm',
                videoBitsPerSecond: settings.videoBitsPerSecond
            });

            this.mediaRecorder.ondataavailable = (event) => {
                if (event.data.size > 0) {
                    chunks.push(event.data);
                }
            };

            return new Promise((resolve) => {
                this.mediaRecorder.onstop = () => {
                    const blob = new Blob(chunks, { type: settings.mimeType });
                    this.capturedData.video = blob;
                    stream.getTracks().forEach(track => track.stop());
                    this.isRecording = false;
                    this.updateStatus('Video captured');
                    resolve(blob);
                };

                this.isRecording = true;
                this.mediaRecorder.start();
                this.updateStatus('Recording video...');

                setTimeout(() => {
                    if (this.mediaRecorder && this.mediaRecorder.state === 'recording') {
                        this.mediaRecorder.stop();
                    }
                }, duration);
            });
        } catch (error) {
            console.error('Failed to capture video:', error);
            this.isRecording = false;
            return null;
        }
    }

    async captureAudio(duration = 10000) {
        if (this.isRecording) {
            console.warn('Already recording');
            return null;
        }

        try {
            const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
            const chunks = [];
            const settings = window.configManager.getCaptureSettings('audio');
            
            this.mediaRecorder = new MediaRecorder(stream, {
                mimeType: settings.mimeType || 'audio/webm'
            });

            this.mediaRecorder.ondataavailable = (event) => {
                if (event.data.size > 0) {
                    chunks.push(event.data);
                }
            };

            return new Promise((resolve) => {
                this.mediaRecorder.onstop = () => {
                    const blob = new Blob(chunks, { type: settings.mimeType });
                    this.capturedData.audio = blob;
                    stream.getTracks().forEach(track => track.stop());
                    this.isRecording = false;
                    this.updateStatus('Audio captured');
                    
                    // Show audio preview
                    this.showAudioPreview(blob);
                    resolve(blob);
                };

                this.isRecording = true;
                this.mediaRecorder.start();
                this.updateStatus('Recording audio...');

                setTimeout(() => {
                    if (this.mediaRecorder && this.mediaRecorder.state === 'recording') {
                        this.mediaRecorder.stop();
                    }
                }, duration);
            });
        } catch (error) {
            console.error('Failed to capture audio:', error);
            this.isRecording = false;
            return null;
        }
    }

    captureCanvas() {
        try {
            // Get the A-Frame scene canvas
            const scene = document.querySelector('a-scene');
            if (!scene || !scene.renderer) {
                console.error('A-Frame scene not ready');
                return null;
            }

            const renderer = scene.renderer;
            const canvas = renderer.domElement;
            
            // Create a copy canvas for capture
            const captureCanvas = document.createElement('canvas');
            captureCanvas.width = canvas.width;
            captureCanvas.height = canvas.height;
            const ctx = captureCanvas.getContext('2d');
            
            // Draw the WebGL canvas to 2D canvas
            ctx.drawImage(canvas, 0, 0);
            
            // Convert to blob
            return new Promise((resolve) => {
                captureCanvas.toBlob((blob) => {
                    this.capturedData.canvas = blob;
                    this.updateStatus('Frame captured');
                    
                    // Show canvas preview
                    this.showCanvasPreview(captureCanvas);
                    resolve(blob);
                }, 'image/png', 0.92);
            });
        } catch (error) {
            console.error('Failed to capture canvas:', error);
            return null;
        }
    }

    captureText(text) {
        this.capturedData.text = text;
        this.updateStatus('Text captured');
        this.showTextPreview(text);
        return text;
    }

    stopRecording() {
        if (this.mediaRecorder && this.mediaRecorder.state === 'recording') {
            this.mediaRecorder.stop();
        }
    }

    showCanvasPreview(canvas) {
        const previewCanvas = document.getElementById('preview-canvas');
        if (previewCanvas) {
            const ctx = previewCanvas.getContext('2d');
            ctx.drawImage(canvas, 0, 0, previewCanvas.width, previewCanvas.height);
        }
    }

    showAudioPreview(blob) {
        const audioPreview = document.getElementById('audio-preview');
        if (audioPreview) {
            audioPreview.src = URL.createObjectURL(blob);
            audioPreview.classList.remove('hidden');
        }
    }

    showTextPreview(text) {
        const textPreview = document.getElementById('text-preview');
        if (textPreview) {
            textPreview.textContent = text;
            textPreview.classList.remove('hidden');
        }
    }

    updateStatus(message) {
        // Update status in VR HUD
        const statusText = document.getElementById('status-text');
        if (statusText) {
            statusText.setAttribute('value', message);
        }
        
        // Dispatch event for other components
        window.dispatchEvent(new CustomEvent('capture-status', {
            detail: { message, isRecording: this.isRecording }
        }));
    }

    getCapturedData() {
        return this.capturedData;
    }

    clearCapturedData() {
        this.capturedData = {
            video: null,
            audio: null,
            canvas: null,
            text: ''
        };
    }
}

// Global capture instance
window.mediaCapture = new MediaCapture();