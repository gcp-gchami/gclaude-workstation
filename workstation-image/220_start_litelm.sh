#!/bin/bash
# Start LiteLM proxy server in the background on port 4000

echo "=== Starting LiteLM Proxy Service ==="

# Create and make log file writable by all users so the 'user' account can write to it
touch /var/log/litelm.log
chmod 666 /var/log/litelm.log

# Run litellm as the non-root 'user' in the background, routing to Vertex AI models
runuser -l user -c "litellm --config /etc/litelm/config.yaml --port 4000 --host 0.0.0.0 --num_workers 2 > /var/log/litelm.log 2>&1 &"

echo "LiteLM Proxy launched successfully on port 4000 in the background."
