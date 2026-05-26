#!/bin/bash
# Startup script to start the gcloud Cloud Run proxy in the background and dynamically generate/retrieve the user's specific virtual API key.

echo "[LITELLM PROXY] Starting initialization..." > /proc/1/fd/1

# Initialize log files
LOG_FILE="/var/log/litellm_proxy.log"
touch "$LOG_FILE"
chmod 666 "$LOG_FILE"

# Detect Workstation ID from WEB_HOST or fallback to GCE hostname
if [ -n "$WEB_HOST" ]; then
  CLEAN_HOST="${WEB_HOST#https://}"
  FIRST_PART="${CLEAN_HOST%%.*}"
  if [[ "$FIRST_PART" =~ ^[0-9]+-(.+)$ ]]; then
    WORKSTATION_ID="${BASH_REMATCH[1]}"
  else
    WORKSTATION_ID="$FIRST_PART"
  fi
else
  GCE_HOSTNAME=$(hostname)
  if [[ "$GCE_HOSTNAME" =~ workstations-[a-zA-Z0-9]+-(.+)-[a-zA-Z0-9]+$ ]]; then
    WORKSTATION_ID="${BASH_REMATCH[1]}"
  else
    WORKSTATION_ID="user"
  fi
fi

# Sanitize WORKSTATION_ID to strictly conform to Secret Manager naming limits: [a-zA-Z0-9_-]
# Convert uppercase letters to lowercase and replace any special characters (like dots) with hyphens
SANITIZED_ID=$(echo "$WORKSTATION_ID" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9_-]/-/g')

echo "[LITELLM PROXY] Resolved Workstation User ID: ${WORKSTATION_ID} (Sanitized: ${SANITIZED_ID})" > /proc/1/fd/1

# Dynamic Proxy Configuration
SERVICE_NAME="${LITELLM_SERVICE_NAME:-litellm-proxy}"
REGION_NAME="${CLOUD_ML_REGION:-us-central1}"

# Launch secure gcloud proxy in the background on port 4000
if id -u "user" >/dev/null 2>&1; then
  chown user:user "$LOG_FILE"
  echo "[LITELLM PROXY] Starting local secure gcloud proxy as user 'user' for service '${SERVICE_NAME}' in region '${REGION_NAME}' on port 4000..." > /proc/1/fd/1
  su - user -c "gcloud run services proxy ${SERVICE_NAME} --region=${REGION_NAME} --port=4000 > /var/log/litellm_proxy.log 2>&1 &"
else
  echo "[LITELLM PROXY] Starting local secure gcloud proxy as root for service '${SERVICE_NAME}' in region '${REGION_NAME}' on port 4000..." > /proc/1/fd/1
  gcloud run services proxy ${SERVICE_NAME} --region=${REGION_NAME} --port=4000 > /var/log/litellm_proxy.log 2>&1 &
fi

# Wait for local proxy to be responsive
echo "[LITELLM PROXY] Waiting for local proxy to start up..." > /proc/1/fd/1
PROXY_SUCCESS=false
for i in {1..30}; do
  if curl -s --connect-timeout 2 -I http://localhost:4000 >/dev/null; then
    echo "[LITELLM PROXY] Local proxy is responsive!" > /proc/1/fd/1
    PROXY_SUCCESS=true
    break
  fi
  sleep 1
done

if [ "$PROXY_SUCCESS" = false ]; then
  echo "[LITELLM PROXY] ERROR: Local proxy failed to become responsive on port 4000 after 30 seconds." > /proc/1/fd/1
  echo "[LITELLM PROXY] --- START OF PROXY LOGS ---" > /proc/1/fd/1
  cat "$LOG_FILE" > /proc/1/fd/1
  echo "[LITELLM PROXY] --- END OF PROXY LOGS ---" > /proc/1/fd/1
  exit 1
fi

# Detect GCP Project ID from Metadata Server
PROJECT_ID=$(curl -s -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/project/project-id)
if [ -z "$PROJECT_ID" ]; then
  echo "[LITELLM PROXY] ERROR: Failed to detect Google Cloud Project ID!" > /proc/1/fd/1
  exit 1
fi

SECRET_NAME="litellm-user-key-${SANITIZED_ID}"

# Retrieve existing virtual key from Secret Manager
USER_KEY=$(gcloud secrets versions access latest --secret="${SECRET_NAME}" --project="${PROJECT_ID}" 2>/dev/null)

if [ -z "$USER_KEY" ]; then
  echo "[LITELLM PROXY] Key not found in Secret Manager. Generating a new virtual key dynamically from LiteLLM..." > /proc/1/fd/1
  
  # Fetch LiteLLM master key to authorize key generation request
  MASTER_KEY=$(gcloud secrets versions access latest --secret="litellm-master-key" --project="${PROJECT_ID}" 2>/dev/null)
  
  if [ -z "$MASTER_KEY" ]; then
    echo "[LITELLM PROXY] ERROR: Failed to fetch LiteLLM master key from Secret Manager!" > /proc/1/fd/1
    exit 1
  fi

  # Call local proxy to generate a virtual key with user limits
  RESPONSE=$(curl -s -X POST "http://localhost:4000/key/generate" \
    -H "Authorization: Bearer ${MASTER_KEY}" \
    -H "Content-Type: application/json" \
    -d "{\"key_alias\": \"${SANITIZED_ID}\", \"user_id\": \"${SANITIZED_ID}\"}")

  # Parse the generated key using python
  USER_KEY=$(echo "$RESPONSE" | python3 -c "import sys, json; print(json.load(sys.stdin).get('key', ''))" 2>/dev/null)

  if [ -z "$USER_KEY" ] || [ "$USER_KEY" = "None" ]; then
    echo "[LITELLM PROXY] ERROR: Failed to generate key from LiteLLM proxy! Response: ${RESPONSE}" > /proc/1/fd/1
    exit 1
  fi

  echo "[LITELLM PROXY] Successfully generated new virtual API key." > /proc/1/fd/1

  # Save the new virtual key in Secret Manager for future workstation starts
  echo -n "$USER_KEY" | gcloud secrets versions add "${SECRET_NAME}" --project="${PROJECT_ID}" --data-file=- >/dev/null
  echo "[LITELLM PROXY] Saved new virtual API key in Secret Manager: ${SECRET_NAME}" > /proc/1/fd/1
else
  echo "[LITELLM PROXY] Successfully retrieved existing virtual API key from Secret Manager." > /proc/1/fd/1
fi

# Configure ~/.claude/settings.json
USER_HOME="/home/user"
CLAUDE_DIR="${USER_HOME}/.claude"
mkdir -p "$CLAUDE_DIR"

cat <<EOF > "${CLAUDE_DIR}/settings.json"
{
  "model": "claude-opus-4-6",
  "env": {
    "ANTHROPIC_BASE_URL": "http://localhost:4000",
    "ANTHROPIC_API_KEY": "${USER_KEY}"
  }
}
EOF

# Ensure user 'user' has ownership
chown -R user:user "$CLAUDE_DIR"
chmod 700 "$CLAUDE_DIR"
chmod 600 "${CLAUDE_DIR}/settings.json"

echo "[LITELLM PROXY] Successfully configured settings.json at ${CLAUDE_DIR}/settings.json" > /proc/1/fd/1
