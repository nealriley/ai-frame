# 2D Mode Documentation

## Overview
The 2D mode provides a browser-based 3D visualization for testing and using the AR persistence system without requiring WebXR hardware. This allows for easier development, testing, and demonstration of the persistence features.

## Features

### 1. Dual Mode Support
- **2D Mode**: Three.js-based 3D scene viewable in any browser
- **XR Mode**: Full WebXR AR experience for compatible devices
- **Seamless Switching**: Transfer from 2D preview to XR with one click

### 2. Full API Integration
- Same endpoints as XR mode (`/ar/{session}/objects`)
- Complete save/load functionality
- Real-time persistence to disk
- Session management (new, continue, demo, custom)

### 3. 2D Mode Controls
- **Place Cube**: Add objects to the scene
- **Change Color**: Cycle through 12 colors
- **Undo**: Remove last placed object
- **Clear All**: Remove all objects from session
- **Camera**: Right-click drag to orbit, scroll to zoom

## Files

### Main Files
- `ar-persistent-2d.html` - Combined 2D/XR interface
- `ar-persistent.html` - Original XR-only interface
- `test-2d-mode.html` - Integration testing page

### Key Differences from XR Version

| Feature | XR Mode | 2D Mode |
|---------|---------|---------|
| Hardware | Quest/XR device required | Any browser |
| Controls | Hand tracking/controllers | Mouse/keyboard |
| Placement | Ray-cast to real surfaces | Random positions or click |
| Camera | Head tracking | Mouse orbit control |
| Immersion | Full AR | 3D scene in browser |

## Session Flow

### Starting a Session (2D Mode)
1. User selects session type (new/continue/demo/custom)
2. System loads any existing objects from API
3. Three.js scene initializes with loaded objects
4. User can place new objects with button/click
5. Objects auto-save to API on placement

### Switching to XR
1. Click "Enter AR" button (if XR supported)
2. Session ID saved to localStorage
3. Redirect to XR version
4. XR version auto-loads same session
5. All objects appear in AR space

## API Integration

### Save Object (2D Mode)
```javascript
// Object placed at random position in 2D scene
const position = [
    Math.sin(angle) * distance,
    0.05,  // Slightly above ground
    Math.cos(angle) * distance
];

// Same API call as XR
await fetch(`${API_BASE}/ar/${sessionId}/objects`, {
    method: 'POST',
    headers: {'Content-Type': 'application/json'},
    body: JSON.stringify({
        id: crypto.randomUUID(),
        type: 'cube',
        position: position,
        metadata: {color: colorIndex, timestamp: Date.now()}
    })
});
```

### Load Objects (2D Mode)
```javascript
// Fetch from API (identical to XR)
const response = await fetch(`${API_BASE}/ar/${sessionId}/objects`);
const data = await response.json();

// Create Three.js meshes
data.objects.forEach(objData => {
    const geometry = new THREE.BoxGeometry(0.1, 0.1, 0.1);
    const material = new THREE.MeshPhongMaterial({
        color: colors[objData.metadata.color]
    });
    const cube = new THREE.Mesh(geometry, material);
    cube.position.set(...objData.position);
    scene.add(cube);
});
```

## Testing

### Using test-2d-mode.html
1. Open http://localhost:8080/test-2d-mode.html
2. Click "Run Full Test Suite"
3. Verify all tests pass:
   - Session clear
   - Object save
   - Object load
   - File persistence

### Manual Testing
1. Open ar-persistent-2d.html
2. Create new session or join "2d-test-demo"
3. Place several cubes
4. Refresh page
5. Continue last session
6. Verify objects persist

### Testing Save Errors
With better error handling, you'll see:
- Network errors: "Network error - object saved locally only"
- Server errors: "Save failed - check console" with status code
- Success: Objects appear with no error message

## Troubleshooting

### Common Issues

1. **Save Failed Error**
   - Check API server is running (`curl http://localhost:3001/status`)
   - Check browser console for CORS errors
   - Verify session ID is valid

2. **Objects Not Loading**
   - Check objects.json exists: `/server/uploads/webxr/{session}/objects.json`
   - Verify API returns objects: `curl http://localhost:3001/ar/{session}/objects`
   - Check browser console for fetch errors

3. **Can't Enter XR**
   - WebXR requires HTTPS (except localhost)
   - Device must support immersive-ar
   - Check browser compatibility

4. **Camera Controls Not Working**
   - Right-click and drag (not left-click)
   - Some browsers require pointer lock permission
   - Try different browser if issues persist

## Performance Considerations

- 2D mode can handle 100s of objects smoothly
- Three.js uses WebGL for hardware acceleration
- Objects beyond view distance are still rendered (no culling)
- For 1000+ objects, consider implementing:
  - Level-of-detail (LOD) system
  - Frustum culling
  - Object pooling

## Future Enhancements

1. **Improved 2D Placement**
   - Click-to-place on ground plane
   - Drag to position objects
   - Visual placement preview

2. **Enhanced Controls**
   - Keyboard shortcuts
   - Multi-select and group operations
   - Copy/paste objects

3. **Visual Improvements**
   - Better lighting and shadows
   - Material variations
   - Skybox/environment maps

4. **Collaboration**
   - WebSocket real-time sync
   - Multiple users in same session
   - User avatars/cursors

## Browser Compatibility

### 2D Mode
- ✅ Chrome/Edge 90+
- ✅ Firefox 85+
- ✅ Safari 14+
- ✅ Mobile browsers

### XR Mode
- ✅ Meta Quest Browser
- ✅ Chrome with WebXR
- ⚠️ Firefox Reality (deprecated)
- ❌ Safari (no WebXR support)