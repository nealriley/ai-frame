#!/bin/bash

echo "==================================="
echo "Image Capture Test"
echo "==================================="

API_BASE="http://localhost:3001"
SESSION="test-capture-$(date +%s)"

echo "Session: $SESSION"
echo ""

# Test 1: Upload a screenshot
echo "1. Testing screenshot upload..."
echo "test screenshot data" > /tmp/test-screenshot.png

curl -X POST ${API_BASE}/upload \
  -F "image=@/tmp/test-screenshot.png" \
  -F "source=webxr" \
  -F "session_id=${SESSION}" \
  -F "capture_type=screenshot" \
  -F "metadata={\"timestamp\":$(date +%s),\"type\":\"xr_screenshot\"}" \
  2>/dev/null | python3 -c "import sys, json; data = json.load(sys.stdin); print(f'  Upload ID: {data.get(\"capture_id\", \"ERROR\")}')"

echo ""

# Test 2: Upload a camera photo
echo "2. Testing camera photo upload..."
echo "test camera data" > /tmp/test-camera.jpg

curl -X POST ${API_BASE}/upload \
  -F "image=@/tmp/test-camera.jpg" \
  -F "source=webxr" \
  -F "session_id=${SESSION}" \
  -F "capture_type=camera_photo" \
  -F "metadata={\"timestamp\":$(date +%s),\"type\":\"xr_camera_photo\"}" \
  2>/dev/null | python3 -c "import sys, json; data = json.load(sys.stdin); print(f'  Upload ID: {data.get(\"capture_id\", \"ERROR\")}')"

echo ""

# Test 3: Check uploaded files
echo "3. Checking uploaded files..."
UPLOAD_DIR="/workspaces/ai-frame/server/uploads/webxr"

if [ -d "$UPLOAD_DIR" ]; then
    echo "  Recent uploads:"
    find $UPLOAD_DIR -type f -name "*.png" -o -name "*.jpg" -o -name "*.jpeg" 2>/dev/null | tail -5 | while read file; do
        echo "    - $(basename $(dirname $file))/$(basename $file)"
    done
    
    echo ""
    echo "  Metadata files:"
    find $UPLOAD_DIR -name "metadata.json" -exec sh -c 'echo "    $(dirname {}): $(cat {} | python3 -c "import sys, json; d=json.load(sys.stdin); print(f\"Type: {d.get(\"capture_type\", \"unknown\")}, Session: {d.get(\"session_id\", \"none\")}\")" 2>/dev/null)"' \; | tail -5
else
    echo "  Upload directory not found"
fi

echo ""
echo "==================================="
echo "Test Complete"
echo "==================================="

# Cleanup
rm -f /tmp/test-screenshot.png /tmp/test-camera.jpg