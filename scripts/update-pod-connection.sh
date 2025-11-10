#!/bin/bash
# ============================================================================
# Auto-update RunPod connection info in config.env
# ============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/../config.env"

# Source config file and export all variables
set -a
source "$CONFIG_FILE"
set +a

echo "=== RunPod Connection Updater ==="
echo

# Check if RunPod API key is set
if [ -z "$RUNPOD_API_KEY" ]; then
    echo "ERROR: RUNPOD_API_KEY not set"
    echo
    echo "To get your API key:"
    echo "1. Go to https://www.runpod.io/console/user/settings"
    echo "2. Click 'API Keys'"
    echo "3. Create or copy your API key"
    echo "4. Add to config.env: RUNPOD_API_KEY=your_key_here"
    echo
    exit 1
fi

# Get all pods
echo "Fetching pod info from RunPod API..."
PODS_JSON=$(curl -s -X POST \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer ${RUNPOD_API_KEY}" \
    -d '{"query": "query Pods { myself { pods { id name runtime { uptimeInSeconds ports { ip isIpPublic privatePort publicPort type } } } } }"}' \
    https://api.runpod.io/graphql)

# Check for errors
if echo "$PODS_JSON" | grep -q "errors"; then
    echo "ERROR: RunPod API request failed"
    echo "$PODS_JSON"
    exit 1
fi

# Find running pod (assuming you have one running pod)
POD_ID=$(echo "$PODS_JSON" | python3 -c "
import sys, json
data = json.load(sys.stdin)
pods = data.get('data', {}).get('myself', {}).get('pods', [])
running_pods = [p for p in pods if p.get('runtime') and p['runtime'].get('uptimeInSeconds', 0) > 0]
if running_pods:
    print(running_pods[0]['id'])
" 2>/dev/null)

if [ -z "$POD_ID" ]; then
    echo "ERROR: No running pods found"
    echo "Start your pod in the RunPod dashboard first"
    exit 1
fi

echo "Found running pod: $POD_ID"

# Extract IP and port
NEW_IP=$(echo "$PODS_JSON" | python3 -c "
import sys, json
data = json.load(sys.stdin)
pods = data.get('data', {}).get('myself', {}).get('pods', [])
for pod in pods:
    if pod.get('id') == '${POD_ID}':
        runtime = pod.get('runtime', {})
        ports = runtime.get('ports', [])
        for port in ports:
            if port.get('privatePort') == 22:  # SSH port
                print(port.get('ip', ''))
                break
" 2>/dev/null)

NEW_PORT=$(echo "$PODS_JSON" | python3 -c "
import sys, json
data = json.load(sys.stdin)
pods = data.get('data', {}).get('myself', {}).get('pods', [])
for pod in pods:
    if pod.get('id') == '${POD_ID}':
        runtime = pod.get('runtime', {})
        ports = runtime.get('ports', [])
        for port in ports:
            if port.get('privatePort') == 22:  # SSH port
                print(port.get('publicPort', ''))
                break
" 2>/dev/null)

if [ -z "$NEW_IP" ] || [ -z "$NEW_PORT" ]; then
    echo "ERROR: Could not extract IP/port from RunPod API response"
    exit 1
fi

echo "New connection details:"
echo "  IP:   $NEW_IP"
echo "  Port: $NEW_PORT"
echo

# Update config.env
echo "Updating config.env..."

# Backup config.env
cp "$CONFIG_FILE" "${CONFIG_FILE}.backup"

# Update IP
sed -i "s/^RUNPOD_HOST=.*/RUNPOD_HOST=${NEW_IP}/" "$CONFIG_FILE"

# Update Port
sed -i "s/^RUNPOD_PORT=.*/RUNPOD_PORT=${NEW_PORT}/" "$CONFIG_FILE"

echo "✓ config.env updated"
echo "  Backup saved to: config.env.backup"
echo

# Test connection
echo "Testing SSH connection..."
source "$CONFIG_FILE"

if timeout 5 ssh -p ${NEW_PORT} -i "$SSH_KEY" \
    -o ConnectTimeout=5 \
    -o StrictHostKeyChecking=accept-new \
    root@${NEW_IP} "echo 'SSH connection successful'" 2>/dev/null; then
    echo "✓ SSH connection test passed!"
    echo
    echo "=== Ready to generate! ==="
    echo "Try: bash flux-generate.sh \"test\" --fast --enhance-ai"
else
    echo "⚠ SSH connection test failed"
    echo "The pod might still be starting up. Wait 30 seconds and try again."
    exit 1
fi
