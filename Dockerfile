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

# Configure SSH
RUN mkdir /var/run/sshd
RUN sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config \
    && sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin no/' /etc/ssh/sshd_config

# Create 'agent' user with sudo privileges
RUN useradd -m -s /bin/bash agent \
    && echo 'agent ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers \
    && echo 'agent:agent' | chpasswd

# Configure NPM to install packages to /home/agent/.npm-global (Persisted in volume!)
ENV NPM_CONFIG_PREFIX=/home/agent/.npm-global
ENV PATH=$PATH:/home/agent/.npm-global/bin

# Add Python user bin to PATH (for pip install --user)
ENV PATH=$PATH:/home/agent/.local/bin

# Copy entrypoint script
COPY entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/entrypoint.sh

WORKDIR /home/agent
EXPOSE 22

ENTRYPOINT ["entrypoint.sh"]
CMD ["/usr/sbin/sshd", "-D"]
