#!/bin/bash
# Startup script to stream shell command logs to the container's standard output (captured by Cloud Logging)

LOG_FILE="/var/log/shell_commands.log"

# Make sure the log file exists and has correct permissions
touch "$LOG_FILE"
chmod 666 "$LOG_FILE"

# Start background stream to container's stdout (PID 1's stdout)
echo "[AUDIT AGENT] Starting shell command logging stream to container stdout..." > /proc/1/fd/1
tail -F "$LOG_FILE" > /proc/1/fd/1 &
