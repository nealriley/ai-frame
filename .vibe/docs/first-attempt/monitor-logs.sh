#!/bin/bash

echo "==================================="
echo "AI Frame Log Monitor"
echo "==================================="
echo "Monitoring API calls in real-time..."
echo ""

# Monitor API server logs
echo "API Server Logs (last 10 lines):"
tmux capture-pane -t aiframe:0.0 -p | tail -10

echo ""
echo "==================================="
echo "Watching for new requests..."
echo "(Press Ctrl+C to stop)"
echo ""

# Watch for changes in the uploads directory
watch -n 1 'echo "=== Latest Activity ===" && \
  tmux capture-pane -t aiframe:0.0 -p | tail -5 && \
  echo "" && \
  echo "=== Session Files ===" && \
  ls -t /workspaces/ai-frame/server/uploads/webxr/ 2>/dev/null | head -5'