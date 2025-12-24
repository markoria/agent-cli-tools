# Agent CLI Tools Docker Environment

[![Docker Hub](https://img.shields.io/docker/v/markoria/agent-cli-tools?label=Docker%20Hub&logo=docker)](https://hub.docker.com/r/markoria/agent-cli-tools)
[![Docker Image Size](https://img.shields.io/docker/image-size/markoria/agent-cli-tools/latest)](https://hub.docker.com/r/markoria/agent-cli-tools)
[![Docker Pulls](https://img.shields.io/docker/pulls/markoria/agent-cli-tools)](https://hub.docker.com/r/markoria/agent-cli-tools)
[![GitHub](https://img.shields.io/github/license/markoria/agent-cli-tools)](https://github.com/markoria/agent-cli-tools)

A modular, persistent Docker environment for running AI agent CLI tools (GitHub Copilot CLI, Claude Code, Gemini) with SSH access and headless Model Context Protocol (MCP) server support.

## Features

- 🤖 **Dynamic Agent Installation** - Install only the tools you need via environment variables
- 🔐 **SSH Access** - Secure shell access with key-based authentication
- 💾 **Persistent Storage** - All authentications, tools, and configurations are saved between restarts
- 🔌 **Headless MCP Servers** - Configure external MCP servers via environment variables
- 🔄 **Auto-Updates** - Optional automatic tool updates on container startup
- 🐍 **Multi-Runtime** - Node.js 22 + Python 3 support

## Quick Start

### Option A: Use Pre-built Image from Docker Hub (Recommended)

1. Create a `docker-compose.yml` file:
   ```bash
   curl -O https://raw.githubusercontent.com/markoria/agent-cli-tools/main/docker-compose.yml
   ```

2. Start the container:
   ```bash
   docker-compose up -d
   ```

### Option B: Build from Source

1. Clone the repository:
   ```bash
   git clone https://github.com/markoria/agent-cli-tools.git
   cd agent-cli-tools
   ```

2. Build and start:
   ```bash
   docker-compose up -d --build
   ```

### 2. (Optional) Setup SSH Key Authentication

For passwordless login, add your SSH public key:

**Option A: Using .env file (Recommended)**

1. Copy the example environment file:
   ```bash
   cp .env.example .env
   ```

2. Edit `.env` and uncomment the SSH key line:
   ```bash
   # Windows (PowerShell - use forward slashes)
   SSH_PUBLIC_KEY_PATH=C:/Users/YourName/.ssh/id_rsa.pub
   
   # Linux/macOS
   SSH_PUBLIC_KEY_PATH=~/.ssh/id_rsa.pub
   ```

3. Uncomment the volume mount in `docker-compose.yml`:
   ```yaml
   volumes:
     - ${SSH_PUBLIC_KEY_PATH}:/home/agent/.ssh/authorized_keys:ro
   ```

4. Restart the container:
   ```bash
   docker-compose down
   docker-compose up -d
   ```

**Option B: Direct path in docker-compose.yml**

Edit `docker-compose.yml` directly:
```yaml
volumes:
  - ~/.ssh/id_rsa.pub:/home/agent/.ssh/authorized_keys:ro
```

**Generate SSH key if you don't have one:**
```bash
ssh-keygen -t rsa -b 4096 -C "your_email@example.com"
```

### 3. Connect via SSH

**With SSH key (passwordless):**
```bash
ssh agent@localhost -p 2222
```

**With password:**
```bash
ssh agent@localhost -p 2222
# Password: agent
```

### 4. Authenticate Your Tools

Once inside the container:

```bash
# GitHub Copilot (requires GitHub CLI authentication)
gh auth login

# Claude Code (requires API key)
export ANTHROPIC_API_KEY=sk-ant-xxxxx
# Or run: claude login

# Gemini CLI (Google OAuth or API key)
gemini auth login
# Or set: export GOOGLE_API_KEY=your-api-key
```

### 5. Use Your Agent Tools

```bash
# GitHub Copilot CLI
github-copilot-cli

# Claude Code
claude

# Gemini CLI
gemini
```

## Installation

### Pull from Docker Hub

```bash
docker pull markoria/agent-cli-tools:latest
```

### Run with Docker CLI

If you prefer using `docker run` instead of `docker-compose`:

```bash
docker run -d \
  --name agent-cli \
  -p 2222:22 \
  -e INSTALL_PACKAGES="@github/copilot @anthropic-ai/claude-code @google/gemini-cli" \
  -v agent_data:/home/agent \
  markoria/agent-cli-tools:latest
```

## Configuration

### Installing Different Tools

Edit the `INSTALL_PACKAGES` and `INSTALL_PIP_PACKAGES` in [docker-compose.yml](docker-compose.yml):

```yaml
environment:
  # NPM packages
  - INSTALL_PACKAGES=@github/copilot @anthropic-ai/claude-code @google/gemini-cli
  
  # Python packages (optional)
  - INSTALL_PIP_PACKAGES=openai anthropic
```

Restart the container:

```bash
docker-compose restart agent-cli
```

### Adding System Tools (Tailscale, Docker CLI, etc.)

For tools requiring system-level installation, edit the [Dockerfile](Dockerfile):

```dockerfile
# Example: Add Tailscale
RUN curl -fsSL https://tailscale.com/install.sh | sh

# Example: Add Docker CLI
RUN curl -fsSL https://get.docker.com | sh
```

Then rebuild:

```bash
docker-compose up -d --build
```

### Configuring Headless MCP Servers

Add MCP servers to your environment in [docker-compose.yml](docker-compose.yml):

```yaml
environment:
  - MCP_FILESYSTEM_URL=http://mcp-filesystem:8000/sse
  - MCP_DATABASE_URL=http://mcp-database:8000/sse
  - MCP_CUSTOM_URL=http://my-mcp-server:3000/sse
```

The entrypoint script will automatically generate the configuration for both GitHub Copilot and Claude.

## Architecture

### Workflow

```
┌─────────────────────────────────────────────────────────┐
│                    Agent CLI Container                   │
│  ┌────────────┐  ┌────────────┐  ┌──────────────────┐  │
│  │  Copilot   │  │   Claude   │  │     Gemini       │  │
│  │    CLI     │  │    Code    │  │      CLI         │  │
│  └──────┬─────┘  └──────┬─────┘  └────────┬─────────┘  │
│         │               │                  │             │
│         └───────────────┴──────────────────┘             │
│                         │                                │
│                  MCP Client Layer                        │
│                         │                                │
└─────────────────────────┼────────────────────────────────┘
                          │
                          │ SSE/HTTP
                          │
        ┌─────────────────┼─────────────────┐
        │                 │                 │
┌───────▼────────┐ ┌──────▼──────┐ ┌───────▼────────┐
│ MCP Filesystem │ │ MCP Database│ │ Custom MCP     │
│    Server      │ │   Server    │ │    Server      │
└────────────────┘ └─────────────┘ └────────────────┘
```

### Directory Structure

```
agent-cli-tools/
├── Dockerfile              # Base image definition
├── entrypoint.sh           # Dynamic setup script
├── docker-compose.yml      # Service orchestration
├── .dockerignore          # Build optimization
└── README.md              # This file
```

### Persistent Data

The `agent_data` volume is mounted to `/home/agent` and contains:

```
/home/agent/
├── .npm-global/           # NPM packages (installed tools)
├── .local/                # Python packages
├── .config/
│   ├── gh/               # GitHub CLI authentication
│   ├── github-copilot/   # Copilot CLI config & MCP settings
│   └── claude-code/      # Claude Code config & MCP settings
├── .anthropic/           # Claude API credentials
└── .ssh/                 # SSH keys and authorized_keys
```

## Advanced Usage

### Enable Auto-Updates

```yaml
environment:
  - CHECK_UPDATES=true
```

### Run Custom Startup Commands

Create a `startup.sh` script and mount it:

```yaml
volumes:
  - ./startup.sh:/home/agent/startup.sh
```

Then modify `entrypoint.sh` to execute it before starting SSH.

### Add More Capabilities

#### Example: Add Tailscale VPN

1. Edit `Dockerfile`:
   ```dockerfile
   RUN curl -fsSL https://tailscale.com/install.sh | sh
   ```

2. Edit `docker-compose.yml`:
   ```yaml
   cap_add:
     - NET_ADMIN
   environment:
     - TAILSCALE_AUTH_KEY=tskey-auth-xxxxx
   ```

3. Edit `entrypoint.sh` (add before SSH start):
   ```bash
   if [ ! -z "$TAILSCALE_AUTH_KEY" ]; then
       tailscaled --tun=userspace-networking &
       sleep 2
       tailscale up --authkey=$TAILSCALE_AUTH_KEY
   fi
   ```

## Environment Variables Reference

| Variable | Purpose | Example |
|----------|---------|---------|
| `INSTALL_PACKAGES` | NPM packages to install | `@github/copilot @anthropic-ai/claude-code @google/gemini-cli` |
| `INSTALL_PIP_PACKAGES` | Python packages to install | `openai anthropic` |
| `CHECK_UPDATES` | Auto-update on startup | `true` or `false` |
| `MCP_*_URL` | MCP server endpoints | `MCP_FILESYSTEM_URL=http://mcp-fs:8000/sse` |
| `ANTHROPIC_API_KEY` | Claude API key | `sk-ant-xxxxx` |
| `GITHUB_TOKEN` | GitHub token (alternative to gh auth) | `ghp_xxxxx` |
| `GOOGLE_API_KEY` | Google/Gemini API key | `AIzaSy...` |

## Troubleshooting

### Tools not installing?

Check container logs:
```bash
docker-compose logs agent-cli
```

### SSH connection refused?

Ensure the container is running:
```bash
docker-compose ps
```

### Lost authentication after rebuild?

The `agent_data` volume persists between restarts but not rebuilds. To preserve:
```bash
# Don't use --build flag when restarting
docker-compose restart
```

### MCP servers not connecting?

Verify the MCP configuration was generated:
```bash
docker exec -it agent-cli cat /home/agent/.config/github-copilot/mcp-config.json
```

## License

MIT

## Contributing

Feel free to submit issues or pull requests for improvements!
