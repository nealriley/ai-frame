# WebXR API Reference Documentation

## Overview
WebXR Device API enables immersive VR and AR experiences in web browsers. This document provides comprehensive reference for implementing WebXR features in the AI Frame project.

## Core Concepts

### Session Types
- **immersive-vr**: Full VR headset experience
- **immersive-ar**: AR experience with real-world passthrough
- **inline**: Non-immersive preview on regular displays

### Reference Spaces
- **viewer**: Origin at viewer's position
- **local**: Origin remains stationary in physical space
- **local-floor**: Origin at floor level with room-scale tracking
- **bounded-floor**: Limited movement area with defined boundaries
- **unbounded**: Unlimited movement area

## Implementation Patterns

### Session Initialization
```javascript
// Check for WebXR support
if (navigator.xr) {
  // Check specific session support
  navigator.xr.isSessionSupported('immersive-ar').then((supported) => {
    if (supported) {
      // Request AR session
      navigator.xr.requestSession('immersive-ar', {
        requiredFeatures: ['local', 'hit-test'],
        optionalFeatures: ['anchors', 'hand-tracking']
      }).then(onSessionStarted);
    }
  });
}
```

### WebGL Context Setup
```javascript
const canvas = document.createElement('canvas');
const gl = canvas.getContext('webgl2', {
  xrCompatible: true,  // Critical for WebXR
  alpha: true,         // Transparent background for AR
  preserveDrawingBuffer: false
});
```

### Render Loop
```javascript
function onXRFrame(time, frame) {
  const session = frame.session;
  session.requestAnimationFrame(onXRFrame);
  
  const pose = frame.getViewerPose(xrRefSpace);
  if (pose) {
    const glLayer = session.renderState.baseLayer;
    
    for (const view of pose.views) {
      const viewport = glLayer.getViewport(view);
      gl.viewport(viewport.x, viewport.y, viewport.width, viewport.height);
      
      // Render scene from view's perspective
      renderScene(view.projectionMatrix, view.transform.matrix);
    }
  }
}
```

## Hit Testing API

### Setup Hit Test Source
```javascript
async function setupHitTesting(session) {
  const viewerSpace = await session.requestReferenceSpace('viewer');
  const hitTestSource = await session.requestHitTestSource({
    space: viewerSpace,
    offsetRay: new XRRay()  // Ray from viewer forward
  });
  return hitTestSource;
}
```

### Process Hit Test Results
```javascript
function processHitTests(frame, hitTestSource, refSpace) {
  const hitTestResults = frame.getHitTestResults(hitTestSource);
  
  if (hitTestResults.length > 0) {
    const hit = hitTestResults[0];
    const pose = hit.getPose(refSpace);
    
    // Use pose.transform.matrix for object placement
    return {
      position: pose.transform.position,
      orientation: pose.transform.orientation,
      matrix: pose.transform.matrix
    };
  }
  return null;
}
```

## Anchors API

### Creating Anchors
```javascript
async function createAnchor(frame, pose, space) {
  try {
    const anchor = await frame.createAnchor(pose, space);
    return anchor;
  } catch (error) {
    console.error('Failed to create anchor:', error);
    return null;
  }
}
```

### Tracking Anchors
```javascript
function updateAnchors(frame) {
  for (const anchor of frame.trackedAnchors) {
    if (anchor.anchorSpace) {
      const pose = frame.getPose(anchor.anchorSpace, xrRefSpace);
      if (pose) {
        // Update anchored object position
        updateObjectTransform(anchor.id, pose.transform.matrix);
      }
    }
  }
}
```

### Anchor Limitations
- Maximum 30 concurrent anchors
- Anchors may lose tracking if device moves too far
- Not all devices support persistent anchors across sessions

## Input Handling

### Controller Input
```javascript
session.addEventListener('select', (event) => {
  const source = event.inputSource;
  const pose = event.frame.getPose(source.targetRaySpace, xrRefSpace);
  
  if (pose) {
    // Handle selection at pose position
    handleSelection(pose.transform);
  }
});
```

### Hand Tracking
```javascript
if (inputSource.hand) {
  for (const joint of inputSource.hand.values()) {
    const jointPose = frame.getJointPose(joint, xrRefSpace);
    if (jointPose) {
      // Render hand joint at position
      renderJoint(jointPose.transform.position, jointPose.radius);
    }
  }
}
```

## Performance Optimization

### Framebuffer Scaling
```javascript
// Reduce resolution for better performance
session.updateRenderState({
  baseLayer: new XRWebGLLayer(session, gl, {
    framebufferScaleFactor: 0.5  // 50% resolution
  })
});
```

### Viewport Scaling
```javascript
// Dynamically adjust viewport based on performance
const scaleFactor = calculateDynamicScale(frameTime);
viewport.width *= scaleFactor;
viewport.height *= scaleFactor;
```

## AR-Specific Considerations

### Environment Blending
```javascript
// Check AR blend mode
if (session.environmentBlendMode === 'opaque') {
  // VR mode - render skybox
} else if (session.environmentBlendMode === 'alpha-blend') {
  // AR mode - transparent background
} else if (session.environmentBlendMode === 'additive') {
  // AR mode - additive blending
}
```

### Lighting Estimation
```javascript
if (frame.getLightEstimate) {
  const lightEstimate = frame.getLightEstimate();
  // Apply to 3D scene lighting
  scene.ambientIntensity = lightEstimate.primaryLightIntensity;
  scene.lightDirection = lightEstimate.primaryLightDirection;
}
```

## Browser Requirements

### Required Features
- Secure context (HTTPS)
- WebGL 2.0 support
- Permission for device sensors

### Device Support
- **Meta Quest 3**: Full AR/VR support
- **Magic Leap**: AR support
- **HoloLens**: AR support via Edge
- **Mobile AR**: Chrome/Edge on Android

## Common Pitfalls

1. **Missing HTTPS**: WebXR requires secure context
2. **Wrong Reference Space**: Using 'local' when 'local-floor' needed
3. **Forgetting xrCompatible**: WebGL context must be XR-compatible
4. **Anchor Limits**: Exceeding 30 anchor maximum
5. **Frame Timing**: Not using requestAnimationFrame correctly

## Testing Resources

### WebXR Emulator
- Chrome Extension for desktop testing
- Simulates various XR devices
- Useful for development without hardware

### Debugging Tools
```javascript
// Log XR capabilities
console.log('XR Supported:', 'xr' in navigator);
console.log('VR Supported:', await navigator.xr.isSessionSupported('immersive-vr'));
console.log('AR Supported:', await navigator.xr.isSessionSupported('immersive-ar'));
```

## Related Specifications
- WebXR Device API: https://www.w3.org/TR/webxr/
- WebXR Hit Test: https://immersive-web.github.io/hit-test/
- WebXR Anchors: https://immersive-web.github.io/anchors/
- WebXR Hand Input: https://immersive-web.github.io/webxr-hand-input/