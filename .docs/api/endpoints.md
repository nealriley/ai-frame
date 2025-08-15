# AI Frame API Documentation

## Supported AI APIs

### OpenAI APIs
- **Base URL**: `https://api.openai.com/v1`
- **Authentication**: Bearer token via `OPENAI_API_KEY`
- **Rate Limits**: 10,000 TPM (tokens per minute) for GPT-4

#### Text Completion
```bash
curl -X POST https://api.openai.com/v1/chat/completions \
  -H "Authorization: Bearer $OPENAI_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "gpt-4",
    "messages": [{"role": "user", "content": "Hello!"}],
    "max_tokens": 150
  }'
```

#### Audio Transcription (Whisper)
```bash
curl -X POST https://api.openai.com/v1/audio/transcriptions \
  -H "Authorization: Bearer $OPENAI_API_KEY" \
  -F "file=@audio.wav" \
  -F "model=whisper-1"
```

#### Vision (GPT-4V)
```bash
curl -X POST https://api.openai.com/v1/chat/completions \
  -H "Authorization: Bearer $OPENAI_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "gpt-4-vision-preview",
    "messages": [{
      "role": "user",
      "content": [{
        "type": "text",
        "text": "What is in this image?"
      }, {
        "type": "image_url",
        "image_url": {"url": "data:image/jpeg;base64,{base64}"}
      }]
    }]
  }'
```

### Anthropic Claude API
- **Base URL**: `https://api.anthropic.com/v1`
- **Authentication**: `x-api-key` header with `ANTHROPIC_API_KEY`
- **Rate Limits**: Varies by plan

#### Text Completion
```bash
curl -X POST https://api.anthropic.com/v1/messages \
  -H "x-api-key: $ANTHROPIC_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "claude-3-sonnet-20240229",
    "max_tokens": 1024,
    "messages": [{"role": "user", "content": "Hello!"}]
  }'
```

## Local/Self-Hosted Options

### Ollama (Local LLM)
- **Installation**: `curl -fsSL https://ollama.com/install.sh | sh`
- **Base URL**: `http://localhost:11434`
- **Models**: llama3, codellama, mistral

```bash
# Start Ollama server
ollama serve

# Pull model
ollama pull llama3

# API call
curl -X POST http://localhost:11434/api/generate \
  -H "Content-Type: application/json" \
  -d '{
    "model": "llama3",
    "prompt": "Hello!",
    "stream": false
  }'
```

### Whisper (Local Audio)
- **Installation**: `pip install openai-whisper`
- **Usage**: `whisper audio.wav --model base`

## Environment Configuration

### Required Environment Variables
```bash
# OpenAI (optional)
export OPENAI_API_KEY="sk-..."

# Anthropic (optional)
export ANTHROPIC_API_KEY="sk-ant-..."

# AI Frame settings
export AI_FRAME_DEFAULT_MODEL="claude-3-sonnet"
export AI_FRAME_LOG_LEVEL="info"
export AI_FRAME_OUTPUT_DIR="./outputs"
```

### API Selection Priority
1. User specified: `--api openai` or `--api claude`
2. Environment default: `AI_FRAME_DEFAULT_MODEL`
3. Availability check: ping APIs, use first responding
4. Fallback: local models (Ollama) if available

## Rate Limiting & Cost Management

### Request Batching
- Group multiple inputs when possible
- Use single API call for related operations
- Cache responses to avoid duplicate requests

### Cost Optimization
- Prefer smaller models for simple tasks
- Use local models for development/testing
- Implement token counting for budget tracking

### Error Handling
- **401 Unauthorized**: Invalid or missing API key
- **429 Rate Limited**: Implement exponential backoff
- **500 Server Error**: Retry with different model/endpoint
- **Network Error**: Fall back to cached responses or local models

## Documentation Links
- **OpenAI API Docs**: https://platform.openai.com/docs/api-reference
- **Anthropic Claude Docs**: https://docs.anthropic.com/claude/reference
- **Ollama API Docs**: https://github.com/ollama/ollama/blob/main/docs/api.md
- **Whisper Docs**: https://openai.com/research/whisper