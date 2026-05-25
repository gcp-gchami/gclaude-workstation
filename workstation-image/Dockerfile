FROM us-central1-docker.pkg.dev/cloud-workstations-images/predefined/code-oss:latest

# Run as root to install global packages
USER root

# Install Claude Code via NPM
RUN npm install -g @anthropic-ai/claude-code

# Install Anti-gravity CLI via the provided script
RUN curl -fsSL https://antigravity.google/cli/install.sh | bash

# Copy command logging profile hook
COPY command_logging.sh /etc/profile.d/command_logging.sh

# Source the hook in system-wide bash.bashrc so it runs for non-login interactive shells as well
RUN echo 'if [ -f /etc/profile.d/command_logging.sh ]; then . /etc/profile.d/command_logging.sh; fi' >> /etc/bash.bashrc

# Copy workstation-startup.d script and make it executable
COPY 010_command_logging.sh /etc/workstation-startup.d/010_command_logging.sh
RUN chmod +x /etc/workstation-startup.d/010_command_logging.sh

# Switch back to the standard user if necessary, or let workstations handle it
# Workstations typically run the container as user `user` with uid 1000
