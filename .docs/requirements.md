# AI Frame Requirements & Success Criteria

## Core Requirements (from INSTRUCTIONS.md)

### Must Have
1. **Terminal-first workflow** - Must run in bash/tmux with documented steps
2. **No GUI dependencies** - CLI only (browser exceptions for WebXR)
3. **Open APIs only** - Use documented/accessible APIs
4. **Human-readable output** - All results logged to disk/stdout
5. **Dependency documentation** - Complete setup.sh with versions

### Success Criteria
- [x] Clean environment initialization (tmux/Codespaces)
- [ ] CLI tools and API configuration working
- [ ] Complete multimodal walkthrough (voice → AI → output)
- [ ] Code with inline documentation links
- [ ] Test validation with mock and real data
- [ ] Challenge/tradeoff documentation

## Technical Specifications

### Environment
- **Platform**: Ubuntu 22.04 (GitHub Codespaces)
- **Shell**: bash
- **Runtimes**: Node.js 22.17.0, Python 3.12.1

### Required Dependencies
- **Audio processing**: ffmpeg (not installed)
- **HTTP requests**: curl ✓
- **JSON processing**: jq ✓
- **Terminal multiplexer**: tmux ✓
- **Package managers**: npm ✓, pip ✓

### Missing Tools to Install
- `ffmpeg` - for audio file processing
- `sox` - alternative audio tool
- Python packages: `openai`, `anthropic`, `requests`, `whisper` (if using OpenAI Whisper)
- Node packages: TBD based on implementation choice

## Interaction Model Design

### Input Sources
1. **Text**: Direct CLI input or file upload
2. **Audio**: WAV/MP3 files → transcription via Whisper API
3. **Image**: Upload to vision-capable AI APIs

### Processing Pipeline
```
Input → Validation → AI API Call → Response Processing → Output + Logging
```

### Output Formats
- **Console**: Colored, formatted terminal output
- **Files**: JSON logs, generated images, processed text
- **Structured**: Machine-readable + human-friendly formats

## Creative Freedom Areas
- Custom naming conventions ("capsules", "skillsets", "canvas")
- Interaction patterns and UX flow
- Multi-modal input/output combinations
- Personal metaphors and interface design

## Non-Negotiable Constraints
- No opaque magic - all steps documented
- No GUI unless browser-served
- Open APIs or explicitly documented credentials
- Human-readable output with disk logging
- Complete dependency listing

## Success Metrics
- Can initialize from scratch in under 5 minutes
- Multimodal workflow works end-to-end
- Documentation enables cold-start by another user
- Error handling and logging captures unexpected behavior
- Creative elements make the interaction feel unique