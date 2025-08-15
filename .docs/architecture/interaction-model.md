# AI Frame Interaction Model

## Core Concept: "Capsule-Based Processing"

Each interaction is a **capsule** containing:
- Input payload (text/audio/image)
- Processing metadata (API choice, parameters)
- Output artifacts (responses, files, logs)
- Temporal context (timestamps, session info)

## Flow Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Input Layer   │───▶│ Processing Hub  │───▶│  Output Layer   │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                        │                        │
    ┌────▼────┐              ┌────▼────┐              ┌────▼────┐
    │  Text   │              │   AI    │              │ Console │
    │  Audio  │              │  APIs   │              │  Files  │
    │  Image  │              │ (OpenAI,│              │  Logs   │
    │  File   │              │Anthropic│              │         │
    └─────────┘              │ Claude) │              └─────────┘
                             └─────────┘
```

## Input Handling

### Text Input
- Direct CLI arguments: `ai-frame "analyze this text"`
- File input: `ai-frame --file input.txt`
- Interactive mode: prompt-based conversation

### Audio Input
- File upload: `ai-frame --audio recording.wav`
- Pipeline: Audio → Whisper API → Text → Main AI API
- Supported formats: WAV, MP3, M4A (via ffmpeg)

### Image Input
- File upload: `ai-frame --image photo.jpg`
- Vision API integration (GPT-4V, Claude-3-Vision)
- Pipeline: Image → Vision API → Description/Analysis

## Processing Hub

### API Router
Intelligent API selection based on:
- Input type (text → Claude/GPT, image → Vision models)
- User preference (configurable via environment)
- Availability/rate limits
- Cost optimization

### Request Pipeline
1. **Input validation** - format, size, type checking
2. **Preprocessing** - format conversion, enhancement
3. **API call** - with retry logic and error handling
4. **Response parsing** - extract content, metadata
5. **Post-processing** - formatting, additional analysis

## Output System

### Console Display
- **Colored output** using terminal ANSI codes
- **Structured format**: Input summary → Processing info → Results
- **Progress indicators** for long-running operations
- **Error highlighting** with clear next steps

### File Artifacts
- **Response logs**: `logs/YYYY-MM-DD-HH-MM-SS-response.json`
- **Generated content**: `outputs/generated-TIMESTAMP.{txt,md,json}`
- **Session history**: `sessions/session-ID.log`

### Logging Strategy
- **Debug**: API calls, processing steps, timing
- **Info**: User actions, successful operations
- **Warn**: Fallbacks, rate limits, degraded service
- **Error**: Failures with actionable suggestions

## Session Management

### Capsule Persistence
Each interaction creates a timestamped capsule:
```json
{
  "id": "capsule-20250814-142356",
  "timestamp": "2025-08-14T14:23:56Z",
  "input": {
    "type": "text",
    "content": "...",
    "source": "cli"
  },
  "processing": {
    "api": "claude-3-sonnet",
    "duration_ms": 1250,
    "tokens": {"input": 42, "output": 156}
  },
  "output": {
    "content": "...",
    "files": ["outputs/response-123.txt"],
    "status": "success"
  }
}
```

### Context Continuity
- **Session linking** for conversational flows
- **Context windows** respecting API limits
- **Memory management** with automatic cleanup

## Error Handling & Resilience

### Graceful Degradation
- API unavailable → fallback to alternative
- Rate limited → queue with backoff
- Invalid input → helpful error messages
- Network issues → offline mode suggestions

### Recovery Patterns
- **Retry logic** with exponential backoff
- **Circuit breaker** for failing services
- **Cache responses** for repeated requests
- **Offline artifacts** for debugging