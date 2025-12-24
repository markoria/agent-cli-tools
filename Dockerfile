# Dockerfile for Agent CLI Tools
# Base image with Node.js 22 (required for GitHub Copilot CLI)
FROM node:22-bookworm

# Install Base Utilities & SSH Server
RUN apt-get update && apt-get install -y \
    openssh-server \
    python3 python3-pip python3-venv \
    curl git sudo jq vim nano \
    && rm -rf /var/lib/apt/lists/*

# Install GitHub CLI (needed for Copilot authentication)
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg \
    && chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
    && apt-get update && apt-get install -y gh \
    && rm -rf /var/lib/apt/lists/*

# Configure SSH (key-only authentication)
RUN mkdir /var/run/sshd
RUN sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config \
    && sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin no/' /etc/ssh/sshd_config \
    && sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config

# Create 'agent' user with sudo privileges (no password - SSH key only)
RUN useradd -m -s /bin/bash agent \
    && echo 'agent ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

# Configure NPM to install packages to /home/agent/.npm-global (Persisted in volume!)
ENV NPM_CONFIG_PREFIX=/home/agent/.npm-global
ENV PATH=$PATH:/home/agent/.npm-global/bin

# Create npm-global directory with correct permissions
RUN mkdir -p /home/agent/.npm-global \
    && chown -R agent:agent /home/agent/.npm-global

# Add Python user bin to PATH (for pip install --user)
ENV PATH=$PATH:/home/agent/.local/bin

# Copy bashrc for agent user (ensures PATH is set on SSH login)
COPY .bashrc /home/agent/.bashrc
RUN chown agent:agent /home/agent/.bashrc

# Copy entrypoint script
COPY entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/entrypoint.sh

WORKDIR /home/agent
EXPOSE 22

ENTRYPOINT ["entrypoint.sh"]
CMD ["/usr/sbin/sshd", "-D"]
