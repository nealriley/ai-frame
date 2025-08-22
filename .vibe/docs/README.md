# AI Frame Technical Documentation

This directory contains comprehensive technical documentation for the AI Frame project, providing detailed reference materials for WebXR development, FastAPI backend implementation, and GitHub Codespaces configuration.

## Documentation Structure

### Core Technology References

#### 📱 [WebXR API Reference](./webxr-reference.md)
Complete guide to WebXR implementation including:
- Session initialization and management
- Hit testing for AR surface detection
- Anchors API for persistent object placement
- Input handling (controllers and hand tracking)
- Performance optimization techniques
- Browser compatibility and requirements

#### 🚀 [FastAPI Reference](./fastapi-reference.md)
Comprehensive backend development guide covering:
- Request/response handling patterns
- Pydantic models and validation
- File uploads and media handling
- WebSocket implementation for real-time sync
- Authentication and security
- Database integration patterns
- Testing strategies

#### ☁️ [GitHub Codespaces Reference](./codespaces-reference.md)
Complete configuration and usage guide including:
- Dev container setup
- Port forwarding configuration
- Environment variables and secrets
- Performance optimization
- Multi-service orchestration
- Debugging and development workflows

#### 🚀 [Codespaces Deployment Guide](./codespaces-deployment.md)
Optimal deployment strategy for AI Frame including:
- tmux-based service orchestration
- Automatic port forwarding and public URLs
- Quest device access configuration
- Environment variable usage
- Command-line tools reference
- Troubleshooting and security

## Quick Links

### WebXR Resources
- [WebXR Samples](https://immersive-web.github.io/webxr-samples/)
- [WebXR Device API Spec](https://www.w3.org/TR/webxr/)
- [Hit Test Module](https://immersive-web.github.io/hit-test/)
- [Anchors Module](https://immersive-web.github.io/anchors/)

### FastAPI Resources
- [FastAPI Documentation](https://fastapi.tiangolo.com/)
- [Pydantic Documentation](https://docs.pydantic.dev/)
- [Uvicorn Server](https://www.uvicorn.org/)

### GitHub Codespaces Resources
- [Codespaces Documentation](https://docs.github.com/en/codespaces)
- [Dev Containers Spec](https://containers.dev/)
- [Available Features](https://github.com/devcontainers/features)

## How to Use This Documentation

### For New Features
1. Check the relevant technology reference for implementation patterns
2. Review code examples and best practices
3. Follow the established patterns in the codebase

### For Debugging
1. Consult the troubleshooting sections
2. Review common pitfalls and solutions
3. Check browser/device requirements

### For Configuration
1. Use the provided configuration templates
2. Adapt settings to project needs
3. Follow security best practices

## Documentation Maintenance

### Adding New Documentation
When adding new documentation:
1. Create a new `.md` file in this directory
2. Follow the existing format and structure
3. Include practical code examples
4. Add links to official documentation
5. Update this README with the new document

### Updating Existing Documentation
When updating documentation:
1. Verify information against official sources
2. Test code examples
3. Mark deprecated features clearly
4. Add version information where relevant

## AI Frame Specific Implementation Notes

### WebXR Considerations
- The project uses `immersive-ar` session mode for Quest 3
- Hit testing is essential for object placement
- Anchors API may not persist across browser sessions
- HTTPS with valid certificates required for WebXR

### FastAPI Architecture
- Session-based object storage in `/server/uploads/`
- UUID-based session management
- Real-time synchronization via WebSockets
- CORS configured for cross-origin WebXR access

### Codespaces Setup
- Ports 3001, 8080, 8443 must be set to PUBLIC for Quest access
- Auto-detection of Codespaces environment in code
- Services orchestrated via tmux or Docker Compose
- Self-signed certificates generated for HTTPS

## Version Information
- Documentation last updated: 2025-08-15
- WebXR API: Latest stable
- FastAPI: 0.100+
- Python: 3.11+
- Node.js: 18+

## Contributing
When contributing to documentation:
1. Ensure accuracy of technical information
2. Include working code examples
3. Document edge cases and limitations
4. Keep language clear and concise
5. Update the table of contents as needed