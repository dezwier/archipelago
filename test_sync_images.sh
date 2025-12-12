#!/bin/bash

# Test script for syncing images from local to Railway

# Default to Railway URL, but allow override
API_URL="${API_URL:-https://archipelago-production.up.railway.app}"

echo "Testing image sync endpoint..."
echo "API URL: $API_URL"
echo ""

# Test the endpoint
response=$(curl -s -w "\n%{http_code}" -X POST "$API_URL/api/v1/concept-image/sync-from-local")

# Extract status code (last line)
http_code=$(echo "$response" | tail -n1)
# Extract body (all but last line)
body=$(echo "$response" | sed '$d')

echo "HTTP Status: $http_code"
echo "Response:"
echo "$body" | python3 -m json.tool 2>/dev/null || echo "$body"

if [ "$http_code" -eq 200 ] || [ "$http_code" -eq 201 ]; then
    echo ""
    echo "✅ Success!"
else
    echo ""
    echo "❌ Failed with status code: $http_code"
    echo ""
    echo "To test locally, set API_URL:"
    echo "  API_URL=http://localhost:8000 ./test_sync_images.sh"
fi
