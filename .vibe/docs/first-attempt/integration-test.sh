#!/bin/bash

echo "==================================="
echo "AI Frame Integration Test"
echo "==================================="

API_BASE="http://localhost:3001"
TEST_SESSION="integration-test-$(date +%s)"

echo -e "\n1. Testing API Health..."
STATUS=$(curl -s ${API_BASE}/status | jq -r '.status')
if [ "$STATUS" = "operational" ]; then
    echo "✅ API is operational"
else
    echo "❌ API is not operational"
    exit 1
fi

echo -e "\n2. Creating new session: $TEST_SESSION"
curl -s -X DELETE ${API_BASE}/ar/${TEST_SESSION}/objects > /dev/null

echo -e "\n3. Saving 3 test objects..."
for i in 1 2 3; do
    RESPONSE=$(curl -s -X POST ${API_BASE}/ar/${TEST_SESSION}/objects \
        -H "Content-Type: application/json" \
        -d "{
            \"type\": \"cube\",
            \"position\": [$i, $((i-2)), -$i],
            \"metadata\": {
                \"color\": $((i+3)),
                \"timestamp\": $(date +%s)
            }
        }")
    
    SUCCESS=$(echo $RESPONSE | jq -r '.success')
    if [ "$SUCCESS" = "true" ]; then
        ID=$(echo $RESPONSE | jq -r '.object.id')
        echo "  ✅ Object $i saved (ID: ${ID:0:8}...)"
    else
        echo "  ❌ Failed to save object $i"
    fi
done

echo -e "\n4. Loading objects back..."
RESPONSE=$(curl -s ${API_BASE}/ar/${TEST_SESSION}/objects)
COUNT=$(echo $RESPONSE | jq -r '.count')
echo "  Found $COUNT objects"

if [ "$COUNT" = "3" ]; then
    echo "  ✅ All objects retrieved successfully"
    
    echo -e "\n5. Verifying object data..."
    echo $RESPONSE | jq -r '.objects[] | "  Position: [\(.position[0]), \(.position[1]), \(.position[2])] Color: \(.metadata.color)"'
else
    echo "  ❌ Expected 3 objects, got $COUNT"
fi

echo -e "\n6. Testing file persistence..."
FILE="/workspaces/ai-frame/server/uploads/webxr/${TEST_SESSION}/objects.json"
if [ -f "$FILE" ]; then
    echo "  ✅ Objects file exists: $FILE"
    FILE_COUNT=$(jq '. | length' $FILE)
    echo "  File contains $FILE_COUNT objects"
else
    echo "  ❌ Objects file not found"
fi

echo -e "\n7. Testing clear operation..."
RESPONSE=$(curl -s -X DELETE ${API_BASE}/ar/${TEST_SESSION}/objects)
SUCCESS=$(echo $RESPONSE | jq -r '.success')
if [ "$SUCCESS" = "true" ]; then
    echo "  ✅ Session cleared successfully"
else
    echo "  ❌ Failed to clear session"
fi

echo -e "\n==================================="
echo "Integration Test Complete!"
echo "==================================="