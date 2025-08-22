# Media Capture Documentation

## Overview
Media capture in AI Frame enables users to record and save their AR experiences through screenshots, video recordings, and scene captures. This document covers implementation patterns for capturing media from WebXR sessions.

## Architecture

### Capture Pipeline
```
┌────────────────────────────────────────┐
│         WebXR AR Session               │
│  ┌──────────────────────────────────┐  │
│  │   Canvas/WebGL Context           │  │
│  │   3D Scene Rendering             │  │
│  └──────────────────────────────────┘  │
└────────────────┬───────────────────────┘
                 │
         Capture Trigger (Controller/UI)
                 │
┌────────────────┴───────────────────────┐
│         Capture Processing             │
│  ┌──────────────────────────────────┐  │
│  │   Canvas.toBlob()                │  │
│  │   MediaRecorder API              │  │
│  │   ImageCapture API               │  │
│  └──────────────────────────────────┘  │
└────────────────┬───────────────────────┘
                 │
            Encoding/Compression
                 │
┌────────────────┴───────────────────────┐
│         Storage & Upload               │
│  ┌──────────────────────────────────┐  │
│  │   Local: IndexedDB/FileSystem    │  │
│  │   Remote: Server Upload          │  │
│  └──────────────────────────────────┘  │
└────────────────────────────────────────┘
```

## Screenshot Capture

### Basic Screenshot Implementation
```javascript
class ScreenshotCapture {
    constructor(canvas) {
        this.canvas = canvas;
        this.quality = 0.92; // JPEG quality
        this.format = 'image/jpeg';
    }
    
    async captureScreenshot() {
        return new Promise((resolve, reject) => {
            try {
                // Ensure the frame is rendered
                if (this.renderer) {
                    this.renderer.render(this.scene, this.camera);
                }
                
                // Convert canvas to blob
                this.canvas.toBlob(
                    (blob) => {
                        if (blob) {
                            resolve(blob);
                        } else {
                            reject(new Error('Failed to create blob'));
                        }
                    },
                    this.format,
                    this.quality
                );
            } catch (error) {
                reject(error);
            }
        });
    }
    
    async captureWithMetadata() {
        const blob = await this.captureScreenshot();
        
        const metadata = {
            timestamp: Date.now(),
            session_id: this.sessionId,
            format: this.format,
            size: blob.size,
            dimensions: {
                width: this.canvas.width,
                height: this.canvas.height
            },
            device: this.getDeviceInfo(),
            scene: this.getSceneInfo()
        };
        
        return {
            blob: blob,
            metadata: metadata
        };
    }
    
    async captureHighResolution(scale = 2) {
        // Save original size
        const originalWidth = this.canvas.width;
        const originalHeight = this.canvas.height;
        
        // Temporarily increase resolution
        this.canvas.width = originalWidth * scale;
        this.canvas.height = originalHeight * scale;
        
        // Update viewport and render
        if (this.renderer) {
            this.renderer.setSize(
                this.canvas.width,
                this.canvas.height,
                false
            );
            this.renderer.render(this.scene, this.camera);
        }
        
        // Capture
        const blob = await this.captureScreenshot();
        
        // Restore original size
        this.canvas.width = originalWidth;
        this.canvas.height = originalHeight;
        
        if (this.renderer) {
            this.renderer.setSize(originalWidth, originalHeight, false);
        }
        
        return blob;
    }
}
```

### WebXR-Specific Screenshot
```javascript
class XRScreenshotCapture extends ScreenshotCapture {
    constructor(xrSession, glContext) {
        super();
        this.xrSession = xrSession;
        this.gl = glContext;
        this.preserveDrawingBuffer = true;
    }
    
    async captureXRFrame(frame) {
        const session = frame.session;
        const glLayer = session.renderState.baseLayer;
        
        if (!glLayer || !glLayer.framebuffer) {
            throw new Error('No XR framebuffer available');
        }
        
        // Bind XR framebuffer
        this.gl.bindFramebuffer(
            this.gl.FRAMEBUFFER,
            glLayer.framebuffer
        );
        
        // Get viewport for first view (left eye)
        const pose = frame.getViewerPose(this.referenceSpace);
        if (!pose || !pose.views.length) {
            throw new Error('No viewer pose available');
        }
        
        const view = pose.views[0];
        const viewport = glLayer.getViewport(view);
        
        // Read pixels from framebuffer
        const pixels = new Uint8Array(
            viewport.width * viewport.height * 4
        );
        
        this.gl.readPixels(
            viewport.x,
            viewport.y,
            viewport.width,
            viewport.height,
            this.gl.RGBA,
            this.gl.UNSIGNED_BYTE,
            pixels
        );
        
        // Convert to image
        return this.pixelsToImage(pixels, viewport.width, viewport.height);
    }
    
    pixelsToImage(pixels, width, height) {
        // Create canvas
        const canvas = document.createElement('canvas');
        canvas.width = width;
        canvas.height = height;
        
        const ctx = canvas.getContext('2d');
        const imageData = ctx.createImageData(width, height);
        
        // Flip Y-axis (WebGL coordinate system)
        for (let y = 0; y < height; y++) {
            for (let x = 0; x < width; x++) {
                const srcIdx = (y * width + x) * 4;
                const dstIdx = ((height - y - 1) * width + x) * 4;
                
                imageData.data[dstIdx] = pixels[srcIdx];     // R
                imageData.data[dstIdx + 1] = pixels[srcIdx + 1]; // G
                imageData.data[dstIdx + 2] = pixels[srcIdx + 2]; // B
                imageData.data[dstIdx + 3] = pixels[srcIdx + 3]; // A
            }
        }
        
        ctx.putImageData(imageData, 0, 0);
        
        return new Promise((resolve) => {
            canvas.toBlob(resolve, 'image/png');
        });
    }
}
```

## Video Recording

### MediaRecorder Implementation
```javascript
class VideoRecorder {
    constructor(canvas) {
        this.canvas = canvas;
        this.mediaRecorder = null;
        this.chunks = [];
        this.isRecording = false;
        
        // Recording settings
        this.options = {
            mimeType: 'video/webm;codecs=vp9',
            videoBitsPerSecond: 5000000 // 5 Mbps
        };
        
        // Check for codec support
        this.detectCodecSupport();
    }
    
    detectCodecSupport() {
        const codecs = [
            'video/webm;codecs=vp9,opus',
            'video/webm;codecs=vp8,opus',
            'video/webm;codecs=h264',
            'video/mp4;codecs=h264',
            'video/webm'
        ];
        
        for (const codec of codecs) {
            if (MediaRecorder.isTypeSupported(codec)) {
                this.options.mimeType = codec;
                console.log(`Using codec: ${codec}`);
                break;
            }
        }
    }
    
    startRecording(frameRate = 30) {
        if (this.isRecording) {
            console.warn('Already recording');
            return;
        }
        
        // Create stream from canvas
        const stream = this.canvas.captureStream(frameRate);
        
        // Add audio if available
        this.addAudioTrack(stream);
        
        // Create MediaRecorder
        this.mediaRecorder = new MediaRecorder(stream, this.options);
        
        // Setup event handlers
        this.mediaRecorder.ondataavailable = (event) => {
            if (event.data.size > 0) {
                this.chunks.push(event.data);
            }
        };
        
        this.mediaRecorder.onstart = () => {
            console.log('Recording started');
            this.isRecording = true;
            this.onRecordingStarted();
        };
        
        this.mediaRecorder.onstop = () => {
            console.log('Recording stopped');
            this.isRecording = false;
            this.processRecording();
        };
        
        this.mediaRecorder.onerror = (error) => {
            console.error('Recording error:', error);
            this.isRecording = false;
            this.onRecordingError(error);
        };
        
        // Start recording
        this.mediaRecorder.start(1000); // Capture in 1-second chunks
    }
    
    async addAudioTrack(stream) {
        try {
            // Request microphone access
            const audioStream = await navigator.mediaDevices.getUserMedia({
                audio: {
                    echoCancellation: true,
                    noiseSuppression: true,
                    autoGainControl: true
                }
            });
            
            // Add audio track to stream
            const audioTrack = audioStream.getAudioTracks()[0];
            if (audioTrack) {
                stream.addTrack(audioTrack);
            }
        } catch (error) {
            console.warn('Audio not available:', error);
        }
    }
    
    stopRecording() {
        if (!this.isRecording || !this.mediaRecorder) {
            console.warn('Not recording');
            return Promise.resolve(null);
        }
        
        return new Promise((resolve) => {
            this.mediaRecorder.onstop = () => {
                this.isRecording = false;
                const blob = this.processRecording();
                resolve(blob);
            };
            
            this.mediaRecorder.stop();
            
            // Stop all tracks
            const stream = this.mediaRecorder.stream;
            if (stream) {
                stream.getTracks().forEach(track => track.stop());
            }
        });
    }
    
    processRecording() {
        if (this.chunks.length === 0) {
            return null;
        }
        
        // Create blob from chunks
        const blob = new Blob(this.chunks, {
            type: this.options.mimeType
        });
        
        // Clear chunks
        this.chunks = [];
        
        // Create download link
        this.createDownloadLink(blob);
        
        return blob;
    }
    
    createDownloadLink(blob) {
        const url = URL.createObjectURL(blob);
        const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
        const filename = `ar-recording-${timestamp}.webm`;
        
        const a = document.createElement('a');
        a.href = url;
        a.download = filename;
        a.style.display = 'none';
        document.body.appendChild(a);
        
        // Auto-download (optional)
        // a.click();
        
        // Cleanup after delay
        setTimeout(() => {
            document.body.removeChild(a);
            URL.revokeObjectURL(url);
        }, 100);
        
        return { url, filename };
    }
    
    // Event callbacks
    onRecordingStarted() {
        // Override in subclass
    }
    
    onRecordingError(error) {
        // Override in subclass
    }
}
```

### WebXR Video Recording
```javascript
class XRVideoRecorder extends VideoRecorder {
    constructor(xrSession, canvas) {
        super(canvas);
        this.xrSession = xrSession;
        this.frameCount = 0;
        this.startTime = null;
    }
    
    startXRRecording() {
        this.startRecording(60); // 60 FPS for smooth XR
        this.startTime = performance.now();
        
        // Add XR-specific metadata
        this.metadata = {
            session_type: this.xrSession.mode,
            device: this.getXRDeviceInfo(),
            started: Date.now()
        };
    }
    
    captureXRFrame(time, frame) {
        if (!this.isRecording) return;
        
        this.frameCount++;
        
        // Add frame metadata
        const frameMetadata = {
            frame_number: this.frameCount,
            timestamp: time,
            elapsed: time - this.startTime,
            pose: this.extractPoseData(frame)
        };
        
        // Store metadata for later
        if (!this.frameMetadata) {
            this.frameMetadata = [];
        }
        this.frameMetadata.push(frameMetadata);
    }
    
    extractPoseData(frame) {
        const pose = frame.getViewerPose(this.referenceSpace);
        if (!pose) return null;
        
        return {
            position: {
                x: pose.transform.position.x,
                y: pose.transform.position.y,
                z: pose.transform.position.z
            },
            orientation: {
                x: pose.transform.orientation.x,
                y: pose.transform.orientation.y,
                z: pose.transform.orientation.z,
                w: pose.transform.orientation.w
            }
        };
    }
    
    async stopXRRecording() {
        const videoBlob = await this.stopRecording();
        
        if (!videoBlob) return null;
        
        // Create metadata file
        const metadata = {
            ...this.metadata,
            ended: Date.now(),
            duration: performance.now() - this.startTime,
            frame_count: this.frameCount,
            average_fps: this.frameCount / ((performance.now() - this.startTime) / 1000),
            frames: this.frameMetadata
        };
        
        const metadataBlob = new Blob(
            [JSON.stringify(metadata, null, 2)],
            { type: 'application/json' }
        );
        
        return {
            video: videoBlob,
            metadata: metadataBlob,
            info: metadata
        };
    }
    
    getXRDeviceInfo() {
        return {
            user_agent: navigator.userAgent,
            xr_supported: 'xr' in navigator,
            session_mode: this.xrSession.mode,
            enabled_features: Array.from(this.xrSession.enabledFeatures || [])
        };
    }
}
```

## Image Processing

### Canvas Manipulation
```javascript
class ImageProcessor {
    constructor() {
        this.processingCanvas = document.createElement('canvas');
        this.ctx = this.processingCanvas.getContext('2d');
    }
    
    async processImage(blob, options = {}) {
        const img = await this.blobToImage(blob);
        
        // Set canvas size
        this.processingCanvas.width = options.width || img.width;
        this.processingCanvas.height = options.height || img.height;
        
        // Apply transformations
        if (options.resize) {
            await this.resizeImage(img, options.resize);
        }
        
        if (options.crop) {
            await this.cropImage(img, options.crop);
        }
        
        if (options.filters) {
            await this.applyFilters(img, options.filters);
        }
        
        if (options.watermark) {
            await this.addWatermark(options.watermark);
        }
        
        // Convert back to blob
        return this.canvasToBlob(options.format, options.quality);
    }
    
    async blobToImage(blob) {
        return new Promise((resolve, reject) => {
            const img = new Image();
            img.onload = () => resolve(img);
            img.onerror = reject;
            img.src = URL.createObjectURL(blob);
        });
    }
    
    async resizeImage(img, size) {
        const { width, height, maintainAspectRatio = true } = size;
        
        let targetWidth = width;
        let targetHeight = height;
        
        if (maintainAspectRatio) {
            const aspectRatio = img.width / img.height;
            
            if (width && !height) {
                targetHeight = width / aspectRatio;
            } else if (height && !width) {
                targetWidth = height * aspectRatio;
            } else {
                // Fit within bounds
                const scaleX = width / img.width;
                const scaleY = height / img.height;
                const scale = Math.min(scaleX, scaleY);
                
                targetWidth = img.width * scale;
                targetHeight = img.height * scale;
            }
        }
        
        this.processingCanvas.width = targetWidth;
        this.processingCanvas.height = targetHeight;
        
        // Use high-quality scaling
        this.ctx.imageSmoothingEnabled = true;
        this.ctx.imageSmoothingQuality = 'high';
        
        this.ctx.drawImage(img, 0, 0, targetWidth, targetHeight);
    }
    
    async cropImage(img, crop) {
        const { x, y, width, height } = crop;
        
        this.processingCanvas.width = width;
        this.processingCanvas.height = height;
        
        this.ctx.drawImage(
            img,
            x, y, width, height,  // Source rectangle
            0, 0, width, height   // Destination rectangle
        );
    }
    
    async applyFilters(img, filters) {
        // Draw image first
        this.ctx.drawImage(img, 0, 0);
        
        // Get image data
        const imageData = this.ctx.getImageData(
            0, 0,
            this.processingCanvas.width,
            this.processingCanvas.height
        );
        
        const data = imageData.data;
        
        // Apply filters
        if (filters.brightness) {
            this.adjustBrightness(data, filters.brightness);
        }
        
        if (filters.contrast) {
            this.adjustContrast(data, filters.contrast);
        }
        
        if (filters.saturation) {
            this.adjustSaturation(data, filters.saturation);
        }
        
        if (filters.blur) {
            this.applyBlur(imageData, filters.blur);
        }
        
        // Put processed data back
        this.ctx.putImageData(imageData, 0, 0);
    }
    
    adjustBrightness(data, value) {
        // value: -100 to 100
        const adjustment = (value / 100) * 255;
        
        for (let i = 0; i < data.length; i += 4) {
            data[i] = Math.min(255, Math.max(0, data[i] + adjustment));     // R
            data[i + 1] = Math.min(255, Math.max(0, data[i + 1] + adjustment)); // G
            data[i + 2] = Math.min(255, Math.max(0, data[i + 2] + adjustment)); // B
        }
    }
    
    async addWatermark(watermark) {
        const { text, image, position = 'bottom-right', opacity = 0.5 } = watermark;
        
        this.ctx.save();
        this.ctx.globalAlpha = opacity;
        
        if (text) {
            this.ctx.font = '20px Arial';
            this.ctx.fillStyle = 'white';
            this.ctx.strokeStyle = 'black';
            this.ctx.lineWidth = 2;
            
            const metrics = this.ctx.measureText(text);
            const x = this.calculatePosition(position, metrics.width, 'x');
            const y = this.calculatePosition(position, 20, 'y');
            
            this.ctx.strokeText(text, x, y);
            this.ctx.fillText(text, x, y);
        }
        
        if (image) {
            const img = await this.loadImage(image);
            const x = this.calculatePosition(position, img.width, 'x');
            const y = this.calculatePosition(position, img.height, 'y');
            
            this.ctx.drawImage(img, x, y);
        }
        
        this.ctx.restore();
    }
    
    calculatePosition(position, size, axis) {
        const canvasSize = axis === 'x' 
            ? this.processingCanvas.width 
            : this.processingCanvas.height;
        
        const margin = 10;
        
        switch (position) {
            case 'top-left':
                return margin;
            case 'top-right':
                return axis === 'x' ? canvasSize - size - margin : margin;
            case 'bottom-left':
                return axis === 'x' ? margin : canvasSize - size - margin;
            case 'bottom-right':
                return canvasSize - size - margin;
            case 'center':
                return (canvasSize - size) / 2;
            default:
                return margin;
        }
    }
    
    canvasToBlob(format = 'image/jpeg', quality = 0.92) {
        return new Promise((resolve) => {
            this.processingCanvas.toBlob(resolve, format, quality);
        });
    }
}
```

## Server-Side Storage

### Media Upload API
```python
from fastapi import FastAPI, UploadFile, File, Form
from typing import Optional
import aiofiles
import hashlib
from pathlib import Path
from datetime import datetime

app = FastAPI()

class MediaStorageService:
    def __init__(self, base_path: str = "./uploads"):
        self.base_path = Path(base_path)
        self.base_path.mkdir(exist_ok=True)
        
        # Create subdirectories
        self.screenshots_path = self.base_path / "screenshots"
        self.videos_path = self.base_path / "videos"
        self.thumbnails_path = self.base_path / "thumbnails"
        
        for path in [self.screenshots_path, self.videos_path, self.thumbnails_path]:
            path.mkdir(exist_ok=True)
    
    async def save_screenshot(
        self,
        file: UploadFile,
        session_id: str,
        metadata: dict = None
    ):
        """Save screenshot with metadata"""
        # Generate unique filename
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        file_hash = hashlib.md5(file.filename.encode()).hexdigest()[:8]
        filename = f"screenshot_{timestamp}_{file_hash}.{self.get_extension(file.filename)}"
        
        # Create session directory
        session_path = self.screenshots_path / session_id
        session_path.mkdir(exist_ok=True)
        
        file_path = session_path / filename
        
        # Save file
        async with aiofiles.open(file_path, 'wb') as f:
            content = await file.read()
            await f.write(content)
        
        # Save metadata
        if metadata:
            metadata_path = file_path.with_suffix('.json')
            async with aiofiles.open(metadata_path, 'w') as f:
                import json
                await f.write(json.dumps(metadata, indent=2))
        
        # Generate thumbnail
        thumbnail_path = await self.create_thumbnail(file_path)
        
        return {
            "filename": filename,
            "path": str(file_path),
            "size": len(content),
            "thumbnail": str(thumbnail_path) if thumbnail_path else None,
            "timestamp": timestamp,
            "session_id": session_id
        }
    
    async def save_video(
        self,
        file: UploadFile,
        session_id: str,
        metadata: dict = None
    ):
        """Save video recording"""
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        filename = f"video_{timestamp}.{self.get_extension(file.filename)}"
        
        session_path = self.videos_path / session_id
        session_path.mkdir(exist_ok=True)
        
        file_path = session_path / filename
        
        # Stream large files
        async with aiofiles.open(file_path, 'wb') as f:
            chunk_size = 1024 * 1024  # 1MB chunks
            while chunk := await file.read(chunk_size):
                await f.write(chunk)
        
        # Save metadata
        if metadata:
            metadata_path = file_path.with_suffix('.json')
            async with aiofiles.open(metadata_path, 'w') as f:
                import json
                await f.write(json.dumps(metadata, indent=2))
        
        # Extract video info (duration, resolution, etc.)
        video_info = await self.get_video_info(file_path)
        
        return {
            "filename": filename,
            "path": str(file_path),
            "size": file_path.stat().st_size,
            "duration": video_info.get("duration"),
            "resolution": video_info.get("resolution"),
            "timestamp": timestamp,
            "session_id": session_id
        }
    
    async def create_thumbnail(self, image_path: Path, size=(200, 200)):
        """Create thumbnail for image"""
        try:
            from PIL import Image
            
            img = Image.open(image_path)
            img.thumbnail(size, Image.Resampling.LANCZOS)
            
            thumbnail_filename = f"thumb_{image_path.stem}.jpg"
            thumbnail_path = self.thumbnails_path / thumbnail_filename
            
            img.save(thumbnail_path, "JPEG", quality=85)
            
            return thumbnail_path
            
        except Exception as e:
            print(f"Failed to create thumbnail: {e}")
            return None
    
    async def get_video_info(self, video_path: Path):
        """Extract video metadata"""
        try:
            import subprocess
            import json
            
            cmd = [
                'ffprobe',
                '-v', 'quiet',
                '-print_format', 'json',
                '-show_format',
                '-show_streams',
                str(video_path)
            ]
            
            result = subprocess.run(cmd, capture_output=True, text=True)
            if result.returncode == 0:
                data = json.loads(result.stdout)
                
                # Extract relevant info
                video_stream = next(
                    (s for s in data.get('streams', []) 
                     if s.get('codec_type') == 'video'),
                    {}
                )
                
                return {
                    "duration": float(data.get('format', {}).get('duration', 0)),
                    "resolution": f"{video_stream.get('width')}x{video_stream.get('height')}",
                    "codec": video_stream.get('codec_name'),
                    "bitrate": data.get('format', {}).get('bit_rate')
                }
                
        except Exception as e:
            print(f"Failed to get video info: {e}")
        
        return {}
    
    def get_extension(self, filename: str) -> str:
        """Get file extension"""
        return filename.split('.')[-1].lower() if '.' in filename else 'png'

# API Endpoints
storage_service = MediaStorageService()

@app.post("/api/capture/screenshot")
async def upload_screenshot(
    file: UploadFile = File(...),
    session_id: str = Form(...),
    metadata: Optional[str] = Form(None)
):
    """Upload AR screenshot"""
    metadata_dict = None
    if metadata:
        import json
        try:
            metadata_dict = json.loads(metadata)
        except:
            pass
    
    result = await storage_service.save_screenshot(
        file,
        session_id,
        metadata_dict
    )
    
    return {
        "status": "success",
        "data": result
    }

@app.post("/api/capture/video")
async def upload_video(
    file: UploadFile = File(...),
    session_id: str = Form(...),
    metadata: Optional[str] = Form(None)
):
    """Upload AR video recording"""
    metadata_dict = None
    if metadata:
        import json
        try:
            metadata_dict = json.loads(metadata)
        except:
            pass
    
    result = await storage_service.save_video(
        file,
        session_id,
        metadata_dict
    )
    
    return {
        "status": "success",
        "data": result
    }

@app.get("/api/capture/{session_id}/list")
async def list_captures(
    session_id: str,
    media_type: Optional[str] = None
):
    """List all captures for a session"""
    captures = []
    
    # List screenshots
    if not media_type or media_type == "screenshot":
        screenshot_path = storage_service.screenshots_path / session_id
        if screenshot_path.exists():
            for file in screenshot_path.glob("*.png"):
                captures.append({
                    "type": "screenshot",
                    "filename": file.name,
                    "size": file.stat().st_size,
                    "created": datetime.fromtimestamp(file.stat().st_ctime)
                })
    
    # List videos
    if not media_type or media_type == "video":
        video_path = storage_service.videos_path / session_id
        if video_path.exists():
            for file in video_path.glob("*.webm"):
                captures.append({
                    "type": "video",
                    "filename": file.name,
                    "size": file.stat().st_size,
                    "created": datetime.fromtimestamp(file.stat().st_ctime)
                })
    
    return {
        "session_id": session_id,
        "count": len(captures),
        "captures": captures
    }
```

## Client Upload Implementation

### Upload Manager
```javascript
class MediaUploadManager {
    constructor(apiUrl) {
        this.apiUrl = apiUrl;
        this.uploadQueue = [];
        this.isUploading = false;
        this.maxRetries = 3;
    }
    
    async uploadScreenshot(blob, metadata) {
        const formData = new FormData();
        
        // Add file
        formData.append('file', blob, `screenshot_${Date.now()}.png`);
        
        // Add session ID
        formData.append('session_id', this.sessionId);
        
        // Add metadata
        if (metadata) {
            formData.append('metadata', JSON.stringify(metadata));
        }
        
        try {
            const response = await fetch(`${this.apiUrl}/api/capture/screenshot`, {
                method: 'POST',
                body: formData
            });
            
            if (!response.ok) {
                throw new Error(`Upload failed: ${response.status}`);
            }
            
            const result = await response.json();
            console.log('Screenshot uploaded:', result);
            
            return result;
            
        } catch (error) {
            console.error('Screenshot upload error:', error);
            
            // Add to retry queue
            this.addToQueue({
                type: 'screenshot',
                blob: blob,
                metadata: metadata,
                retries: 0
            });
            
            throw error;
        }
    }
    
    async uploadVideo(blob, metadata) {
        // Check file size
        const maxSize = 100 * 1024 * 1024; // 100MB
        if (blob.size > maxSize) {
            console.warn('Video too large, need chunked upload');
            return this.uploadVideoChunked(blob, metadata);
        }
        
        const formData = new FormData();
        formData.append('file', blob, `video_${Date.now()}.webm`);
        formData.append('session_id', this.sessionId);
        
        if (metadata) {
            formData.append('metadata', JSON.stringify(metadata));
        }
        
        // Show upload progress
        return this.uploadWithProgress(
            `${this.apiUrl}/api/capture/video`,
            formData
        );
    }
    
    async uploadWithProgress(url, formData) {
        return new Promise((resolve, reject) => {
            const xhr = new XMLHttpRequest();
            
            // Track upload progress
            xhr.upload.addEventListener('progress', (e) => {
                if (e.lengthComputable) {
                    const percentComplete = (e.loaded / e.total) * 100;
                    this.onUploadProgress(percentComplete);
                }
            });
            
            xhr.addEventListener('load', () => {
                if (xhr.status === 200) {
                    try {
                        const response = JSON.parse(xhr.responseText);
                        resolve(response);
                    } catch (error) {
                        reject(error);
                    }
                } else {
                    reject(new Error(`Upload failed: ${xhr.status}`));
                }
            });
            
            xhr.addEventListener('error', () => {
                reject(new Error('Upload failed'));
            });
            
            xhr.open('POST', url);
            xhr.send(formData);
        });
    }
    
    async uploadVideoChunked(blob, metadata) {
        const chunkSize = 5 * 1024 * 1024; // 5MB chunks
        const chunks = Math.ceil(blob.size / chunkSize);
        const uploadId = this.generateUploadId();
        
        for (let i = 0; i < chunks; i++) {
            const start = i * chunkSize;
            const end = Math.min(start + chunkSize, blob.size);
            const chunk = blob.slice(start, end);
            
            await this.uploadChunk(chunk, {
                upload_id: uploadId,
                chunk_index: i,
                total_chunks: chunks,
                session_id: this.sessionId,
                metadata: i === 0 ? metadata : null
            });
        }
        
        // Finalize upload
        return this.finalizeChunkedUpload(uploadId);
    }
    
    addToQueue(item) {
        this.uploadQueue.push(item);
        
        if (!this.isUploading) {
            this.processQueue();
        }
    }
    
    async processQueue() {
        if (this.uploadQueue.length === 0) {
            this.isUploading = false;
            return;
        }
        
        this.isUploading = true;
        const item = this.uploadQueue.shift();
        
        try {
            if (item.type === 'screenshot') {
                await this.uploadScreenshot(item.blob, item.metadata);
            } else if (item.type === 'video') {
                await this.uploadVideo(item.blob, item.metadata);
            }
        } catch (error) {
            item.retries++;
            
            if (item.retries < this.maxRetries) {
                // Re-queue for retry
                setTimeout(() => {
                    this.uploadQueue.push(item);
                }, Math.pow(2, item.retries) * 1000); // Exponential backoff
            } else {
                console.error('Max retries reached for upload:', item);
            }
        }
        
        // Process next item
        this.processQueue();
    }
    
    onUploadProgress(percent) {
        // Override in subclass
        console.log(`Upload progress: ${percent.toFixed(2)}%`);
    }
    
    generateUploadId() {
        return 'upload-' + Date.now() + '-' + Math.random().toString(36).substr(2, 9);
    }
}
```

## Performance Optimization

### Efficient Capture Strategies
```javascript
class OptimizedCapture {
    constructor() {
        this.captureCanvas = document.createElement('canvas');
        this.captureContext = this.captureCanvas.getContext('2d');
        this.targetResolution = { width: 1920, height: 1080 };
        this.compressionWorker = null;
    }
    
    initCompressionWorker() {
        const workerCode = `
            self.addEventListener('message', async (e) => {
                const { imageData, quality } = e.data;
                
                // Create off-screen canvas
                const canvas = new OffscreenCanvas(
                    imageData.width,
                    imageData.height
                );
                const ctx = canvas.getContext('2d');
                
                // Put image data
                ctx.putImageData(imageData, 0, 0);
                
                // Convert to blob
                const blob = await canvas.convertToBlob({
                    type: 'image/jpeg',
                    quality: quality
                });
                
                // Send back
                self.postMessage({ blob });
            });
        `;
        
        const blob = new Blob([workerCode], { type: 'application/javascript' });
        this.compressionWorker = new Worker(URL.createObjectURL(blob));
    }
    
    async captureOptimized(sourceCanvas) {
        // Calculate optimal size
        const scale = Math.min(
            this.targetResolution.width / sourceCanvas.width,
            this.targetResolution.height / sourceCanvas.height,
            1 // Don't upscale
        );
        
        const width = Math.floor(sourceCanvas.width * scale);
        const height = Math.floor(sourceCanvas.height * scale);
        
        // Resize if needed
        if (scale < 1) {
            this.captureCanvas.width = width;
            this.captureCanvas.height = height;
            
            this.captureContext.drawImage(
                sourceCanvas,
                0, 0, sourceCanvas.width, sourceCanvas.height,
                0, 0, width, height
            );
        } else {
            this.captureCanvas.width = sourceCanvas.width;
            this.captureCanvas.height = sourceCanvas.height;
            this.captureContext.drawImage(sourceCanvas, 0, 0);
        }
        
        // Get image data
        const imageData = this.captureContext.getImageData(
            0, 0,
            this.captureCanvas.width,
            this.captureCanvas.height
        );
        
        // Compress in worker
        if (this.compressionWorker) {
            return this.compressInWorker(imageData);
        } else {
            return this.compressInMain(imageData);
        }
    }
    
    compressInWorker(imageData) {
        return new Promise((resolve) => {
            this.compressionWorker.onmessage = (e) => {
                resolve(e.data.blob);
            };
            
            this.compressionWorker.postMessage({
                imageData: imageData,
                quality: 0.85
            });
        });
    }
    
    async compressInMain(imageData) {
        this.captureContext.putImageData(imageData, 0, 0);
        
        return new Promise((resolve) => {
            this.captureCanvas.toBlob(
                (blob) => resolve(blob),
                'image/jpeg',
                0.85
            );
        });
    }
}
```

## Best Practices

### Capture Guidelines
1. **Use appropriate formats** - JPEG for photos, PNG for UI, WebM for video
2. **Implement compression** - Balance quality vs file size
3. **Handle permissions** properly for camera/microphone
4. **Provide feedback** during capture and upload
5. **Support offline mode** with local storage
6. **Batch uploads** when possible
7. **Implement retry logic** for failed uploads
8. **Clean up resources** after capture
9. **Respect privacy** - allow users to review before upload
10. **Optimize for device** capabilities

### Performance Tips
- Use OffscreenCanvas for processing
- Implement Web Workers for compression
- Stream large files instead of loading in memory
- Use appropriate resolution for device
- Implement progressive upload for large files
- Cache processed media locally

### Security Considerations
- Validate file types and sizes
- Sanitize metadata before storage
- Implement upload limits
- Use secure URLs for media access
- Clean up temporary files
- Implement access controls

## References
- [MediaRecorder API](https://developer.mozilla.org/en-US/docs/Web/API/MediaRecorder)
- [Canvas API](https://developer.mozilla.org/en-US/docs/Web/API/Canvas_API)
- [ImageCapture API](https://developer.mozilla.org/en-US/docs/Web/API/ImageCapture)
- [WebCodecs API](https://developer.mozilla.org/en-US/docs/Web/API/WebCodecs_API)