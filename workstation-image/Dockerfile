FROM us-central1-docker.pkg.dev/cloud-workstations-images/predefined/code-oss:latest

# Run as root to install global packages
USER root

# Install Claude Code via NPM
RUN npm install -g @anthropic-ai/claude-code

# Install Anti-gravity CLI via the provided script
RUN curl -fsSL https://antigravity.google/cli/install.sh | bash

# Switch back to the standard user if necessary, or let workstations handle it
# Workstations typically run the container as user `user` with uid 1000
