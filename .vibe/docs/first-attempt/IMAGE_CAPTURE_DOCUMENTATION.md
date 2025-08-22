# Image Capture Documentation

## Overview
The WebXR interface now supports real-time image capture through controller buttons, allowing users to take screenshots and camera photos during AR sessions. All captures are automatically saved to the server with metadata.

## Features

### Button Controls
- **A Button** (📷): Captures a camera photo (JPEG format)
- **B Button** (📸): Takes a screenshot (PNG format)
- **Squeeze**: Saves scene data (objects, positions)

### Capture Types

#### Screenshot (B Button)
- **Format**: PNG
- **Quality**: Full resolution
- **Content**: Rendered AR scene with virtual objects
- **Filename**: `screenshot_{timestamp}.png`
- **Use Case**: Documenting AR object placement

#### Camera Photo (A Button)
- **Format**: JPEG (92% quality)
- **Quality**: High quality passthrough capture
- **Content**: Camera feed with AR overlay
- **Filename**: `camera_{timestamp}.jpg`
- **Use Case**: Real-world documentation with AR context

## Technical Implementation

### Frontend (ar-persistent.html)

```javascript
// Button state tracking
let buttonStates = { aPressed: false, bPressed: false };

// In XR frame loop
for (const inputSource of session.inputSources) {
    if (inputSource.gamepad) {
        const gamepad = inputSource.gamepad;
        
        // A button (index 4)
        if (gamepad.buttons[4]?.pressed && !buttonStates.aPressed) {
            buttonStates.aPressed = true;
            takeCameraPhoto();
        }
        
        // B button (index 5)
        if (gamepad.buttons[5]?.pressed && !buttonStates.bPressed) {
            buttonStates.bPressed = true;
            takeScreenshot();
        }
    }
}
```

### API Upload

```javascript
// Screenshot capture
canvas.toBlob(async (blob) => {
    const formData = new FormData();
    formData.append('image', blob, `screenshot_${timestamp}.png`);
    formData.append('source', 'webxr');
    formData.append('session_id', sessionId);
    formData.append('capture_type', 'screenshot');
    formData.append('metadata', JSON.stringify({
        timestamp: timestamp,
        objects_in_view: objects.length
    }));
    
    await fetch(`${API_BASE}/upload`, {
        method: 'POST',
        body: formData
    });
}, 'image/png');
```

### Backend Storage (api_server.py)

```python
@app.post("/upload")
async def upload_media(
    source: str = Form(),
    session_id: str = Form(),
    capture_type: str = Form(),
    metadata: str = Form(),
    image: UploadFile = File()
):
    # Save to: /uploads/webxr/{capture_id}/
    # Creates: image file + metadata.json
```

## File Storage Structure

```
/server/uploads/webxr/
├── {capture_id}/
│   ├── screenshot_{timestamp}.png
│   └── metadata.json
├── {capture_id}/
│   ├── camera_{timestamp}.jpg
│   └── metadata.json
└── {session_id}/
    └── objects.json  # AR object positions
```

### Metadata Format

```json
{
  "id": "capture-uuid",
  "source": "webxr",
  "session_id": "session-name",
  "timestamp": "2025-08-14T22:00:00",
  "capture_type": "screenshot|camera_photo",
  "objects_in_view": 5,
  "type": "xr_screenshot|xr_camera_photo"
}
```

## API Endpoints

### Upload Image
**POST** `/upload`

Form Data:
- `image`: File (required)
- `source`: "webxr" (required)
- `session_id`: Session identifier (required)
- `capture_type`: "screenshot" | "camera_photo"
- `metadata`: JSON string with additional data

Response:
```json
{
  "capture_id": "uuid",
  "session_id": "session-name",
  "files": ["screenshot_123456.png"],
  "timestamp": "2025-08-14T22:00:00"
}
```

### Retrieve Images
**GET** `/download/{capture_id}/image`

Returns the captured image file.

## Testing

### Manual Test (WebXR)
1. Start AR session in Quest browser
2. Place some AR objects
3. Press B button - see "📸 Screenshot saved!"
4. Press A button - see "📷 Photo saved!"
5. Check `/server/uploads/webxr/` for files

### Automated Test
```bash
./test-image-capture.sh
```

Tests:
- Screenshot upload
- Camera photo upload
- Metadata storage
- File persistence

## Troubleshooting

### Common Issues

1. **Buttons not responding**
   - Check gamepad API support
   - Verify button indices (4 for A, 5 for B)
   - Check buttonStates reset logic

2. **Upload fails**
   - Verify API server is running
   - Check CORS configuration
   - Monitor server logs: `tmux attach -t aiframe`

3. **Images not saved**
   - Check disk space
   - Verify write permissions on uploads directory
   - Check formData construction

4. **Poor image quality**
   - Increase JPEG quality (currently 0.92)
   - Check canvas resolution
   - Verify preserveDrawingBuffer: true

## Performance Considerations

- Image capture is async (non-blocking)
- PNG screenshots are larger but lossless
- JPEG photos are compressed for smaller size
- Each capture creates new HTTP request
- Consider batching for multiple captures

## Future Enhancements

1. **Video Recording**
   - MediaRecorder API for video clips
   - Configurable duration
   - Compression settings

2. **Batch Operations**
   - Upload multiple captures at once
   - Zip download of session images

3. **Image Processing**
   - Thumbnail generation
   - EXIF metadata embedding
   - Watermarking

4. **Gallery View**
   - Web interface to browse captures
   - Filter by session/type
   - Slideshow mode

5. **Cloud Storage**
   - S3/GCS integration
   - CDN delivery
   - Automatic cleanup policies