# Agent CLI Tools Docker Environment

[![Build and Push](https://github.com/markoria/agent-cli-tools/actions/workflows/docker-publish.yml/badge.svg)](https://github.com/markoria/agent-cli-tools/actions/workflows/docker-publish.yml)
[![Docker Hub](https://img.shields.io/badge/Docker%20Hub-markoria%2Fagent--cli--tools-blue?logo=docker)](https://hub.docker.com/r/markoria/agent-cli-tools)
[![Docker Image Size](https://img.shields.io/docker/image-size/markoria/agent-cli-tools/latest?logo=docker)](https://hub.docker.com/r/markoria/agent-cli-tools/tags)
[![Docker Pulls](https://img.shields.io/docker/pulls/markoria/agent-cli-tools?logo=docker)](https://hub.docker.com/r/markoria/agent-cli-tools)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A modular, persistent Docker environment for running AI agent CLI tools (GitHub Copilot CLI, Claude Code, Gemini) with SSH access, webhook API for automation, and headless Model Context Protocol (MCP) server support.

## Features

- 🤖 **Dynamic Agent Installation** - Install only the tools you need via environment variables
- 🔐 **SSH Access** - Secure shell access with key-based authentication
- 🌐 **Webhook API** - HTTP endpoints for event-driven automation and CI/CD integration
- 💾 **Persistent Storage** - All authentications, tools, and configurations are saved between restarts
- 🔌 **Headless MCP Servers** - Configure external MCP servers via environment variables
- 🔄 **Auto-Updates** - Optional automatic tool updates on container startup
- 🐍 **Multi-Runtime** - Node.js 22 + Python 3 support
- ⚡ **High Performance** - Go-based webhook server (~50k req/s, 6MB binary)

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

**Basic usage (SSH only):**
```bash
docker run -d \
  --name agent-cli \
  -p 2222:22 \
  -e INSTALL_PACKAGES="@github/copilot @anthropic-ai/claude-code @google/gemini-cli" \
  -v agent_data:/home/agent \
  markoria/agent-cli-tools:latest
```

**With webhook support:**
```bash
docker run -d \
  --name agent-cli \
  -p 2222:22 \
  -p 8080:8080 \
  -e INSTALL_PACKAGES="@github/copilot @anthropic-ai/claude-code @google/gemini-cli" \
  -e WEBHOOK_SECRET="$(openssl rand -hex 32)" \
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

### Enabling Webhook API

The webhook server allows HTTP-based automation and integration with CI/CD pipelines, chatbots, and external services.

**1. Generate a secure webhook secret:**

```bash
# Linux/macOS
openssl rand -hex 32

# Windows (PowerShell)
-join ((1..32) | ForEach-Object { '{0:X2}' -f (Get-Random -Maximum 256) })
```

**2. Add to your `.env` file:**

```bash
WEBHOOK_SECRET=your_generated_secret_here
```

**3. Restart the container:**

```bash
docker-compose down
docker-compose up -d
```

The webhook server will be available at `http://localhost:8080` with these endpoints:

- `POST /webhook/copilot` - GitHub Copilot CLI
- `POST /webhook/claude` - Claude Code
- `POST /webhook/gemini` - Google Gemini CLI
- `GET /health` - Health check (no auth required)

**Example webhook request:**

```bash
curl -X POST http://localhost:8080/webhook/copilot \
  -H "Authorization: Bearer your_generated_secret_here" \
  -H "Content-Type: application/json" \
  -d '{
    "prompt": "explain async/await in JavaScript",
    "timeout": 30
  }'
```

**Response:**

```json
{
  "success": true,
  "output": "Async/await is a modern way to handle asynchronous operations...",
  "agent": "copilot"
}
```

See [Webhook Usage Examples](#webhook-usage-examples) below for more use cases.

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
┌─────────────────────────────────────────────────────────────────┐
│                    Agent CLI Container                           │
│                                                                   │
│  ┌───────────────┐  ┌────────────┐  ┌──────────────────────┐   │
│  │ Webhook Server│  │ SSH Server │  │   Agent CLI Tools     │   │
│  │   (Go, :8080) │  │   (:22)    │  │ - Copilot - Claude    │   │
│  │               │  │            │  │ - Gemini              │   │
│  └───────┬───────┘  └─────┬──────┘  └──────────┬───────────┘   │
│          │                 │                     │               │
│          │ HTTP/REST       │ SSH                │ MCP/SSE       │
│          │                 │                     │               │
└──────────┼─────────────────┼─────────────────────┼───────────────┘
           │                 │                     │
           ↓                 ↓                     ↓
    ┌──────────────┐  ┌──────────┐      ┌──────────────────┐
    │ CI/CD        │  │ Terminal │      │  MCP Servers     │
    │ Webhooks     │  │ User     │      │ (Filesystem, DB) │
    │ Automation   │  │          │      │                  │
    └──────────────┘  └──────────┘      └──────────────────┘
```

**Access Methods:**

1. **SSH (Interactive)** - Manual access via terminal: `ssh agent@localhost -p 2222`
2. **Webhook (Automation)** - Event-driven via HTTP API: `POST http://localhost:8080/webhook/{agent}`
3. **MCP (Extensions)** - Enhanced capabilities via external servers
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
├── Dockerfile              # Multi-stage build (Go + Node.js)
├── webhook-server.go       # Go HTTP server for webhooks
├── entrypoint.sh           # Dynamic setup script
├── docker-compose.yml      # Service orchestration
├── .env.example           # Environment variables template
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

### Webhook Usage Examples

The webhook API enables powerful automation scenarios for AI agents.

#### 1. CI/CD Integration - Automated Code Reviews

**GitHub Actions workflow:**

```yaml
# .github/workflows/ai-review.yml
name: AI Code Review
on: [pull_request]

jobs:
  review:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Get PR diff
        id: diff
        run: |
          git diff origin/${{ github.base_ref }}...HEAD > changes.diff
          DIFF=$(cat changes.diff)
          echo "diff<<EOF" >> $GITHUB_OUTPUT
          echo "$DIFF" >> $GITHUB_OUTPUT
          echo "EOF" >> $GITHUB_OUTPUT
      
      - name: AI Code Review
        run: |
          curl -X POST https://your-server.com:8080/webhook/copilot \
            -H "Authorization: Bearer ${{ secrets.WEBHOOK_SECRET }}" \
            -H "Content-Type: application/json" \
            -d "{\"prompt\": \"Review this code and suggest improvements: ${{ steps.diff.outputs.diff }}\", \"timeout\": 120}"
```

#### 2. Slack/Discord Bot Integration

**Slash command bot (Node.js example):**

```javascript
// Slack bot that forwards requests to AI agents
app.command('/ask-copilot', async ({ command, ack, respond }) => {
  await ack();
  
  const response = await fetch('http://agent-cli:8080/webhook/copilot', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${process.env.WEBHOOK_SECRET}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({
      prompt: command.text,
      timeout: 60
    })
  });
  
  const result = await response.json();
  await respond({
    text: result.success ? result.output : `Error: ${result.error}`
  });
});
```

#### 3. Scheduled Automation with Cron

**Daily code quality reports:**

```bash
# crontab entry: Run every day at 9 AM
0 9 * * * curl -X POST http://localhost:8080/webhook/claude \
  -H "Authorization: Bearer $(cat /secrets/webhook_token)" \
  -H "Content-Type: application/json" \
  -d '{"prompt":"Analyze /project/src for code quality issues and generate a report","timeout":300}' \
  | jq '.output' | mail -s "Daily Code Quality Report" team@company.com
```

#### 4. Jira/Issue Tracker Webhooks

**Auto-generate documentation when issues are closed:**

```python
# Flask webhook handler
@app.route('/jira-webhook', methods=['POST'])
def jira_webhook():
    event = request.json
    
    if event['webhookEvent'] == 'jira:issue_updated':
        if event['issue']['fields']['status']['name'] == 'Done':
            # Generate docs for completed feature
            response = requests.post(
                'http://agent-cli:8080/webhook/copilot',
                headers={'Authorization': f'Bearer {WEBHOOK_SECRET}'},
                json={
                    'prompt': f"Generate user documentation for: {event['issue']['fields']['summary']}",
                    'timeout': 120
                }
            )
            
            # Post docs back to Jira
            docs = response.json()['output']
            update_jira_comment(event['issue']['key'], docs)
    
    return '', 200
```

#### 5. API Gateway Pattern

**Expose AI agents to microservices:**

```yaml
# docker-compose.yml - Add nginx reverse proxy
services:
  nginx:
    image: nginx:alpine
    ports:
      - "443:443"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf
      - ./ssl:/etc/nginx/ssl
    depends_on:
      - agent-cli

  agent-cli:
    # ... existing config
    ports:
      - "8080"  # Internal only, accessed via nginx
```

**Nginx config with rate limiting:**

```nginx
# nginx.conf
http {
    limit_req_zone $binary_remote_addr zone=ai_agents:10m rate=10r/m;
    
    server {
        listen 443 ssl;
        ssl_certificate /etc/nginx/ssl/cert.pem;
        ssl_certificate_key /etc/nginx/ssl/key.pem;
        
        location /api/ai/ {
            limit_req zone=ai_agents burst=5;
            
            rewrite ^/api/ai/(.*)$ /webhook/$1 break;
            proxy_pass http://agent-cli:8080;
            proxy_set_header Authorization "Bearer ${WEBHOOK_SECRET}";
        }
    }
}
```

#### 6. Event-Driven Architecture

**AWS Lambda + EventBridge:**

```python
# lambda_function.py
import boto3
import requests
import os

def lambda_handler(event, context):
    """Trigger AI agent on S3 file upload"""
    
    bucket = event['Records'][0]['s3']['bucket']['name']
    key = event['Records'][0]['s3']['object']['key']
    
    if key.endswith('.py'):
        # Analyze newly uploaded Python file
        response = requests.post(
            os.environ['AGENT_WEBHOOK_URL'] + '/webhook/claude',
            headers={'Authorization': f"Bearer {os.environ['WEBHOOK_SECRET']}"},
            json={
                'prompt': f'Review this Python file for security issues: s3://{bucket}/{key}',
                'timeout': 90
            }
        )
        
        result = response.json()
        
        # Send to SNS if issues found
        if 'security' in result['output'].lower():
            sns = boto3.client('sns')
            sns.publish(
                TopicArn=os.environ['ALERT_TOPIC'],
                Subject='Security Review Alert',
                Message=result['output']
            )
    
    return {'statusCode': 200}
```

#### 7. Webhook Request Examples

**Basic request:**

```bash
curl -X POST http://localhost:8080/webhook/copilot \
  -H "Authorization: Bearer your_secret_token" \
  -H "Content-Type: application/json" \
  -d '{"prompt":"explain docker multi-stage builds"}'
```

**With custom timeout:**

```bash
curl -X POST http://localhost:8080/webhook/claude \
  -H "Authorization: Bearer your_secret_token" \
  -H "Content-Type: application/json" \
  -d '{
    "prompt": "Refactor this 1000-line function",
    "timeout": 180
  }'
```

**Health check:**

```bash
curl http://localhost:8080/health
# Response: {"status":"healthy","service":"agent-webhook-server"}
```

**Error handling:**

```bash
# Invalid token
curl -X POST http://localhost:8080/webhook/copilot \
  -H "Authorization: Bearer wrong_token" \
  -H "Content-Type: application/json" \
  -d '{"prompt":"test"}'
# Response: 401 Unauthorized

# Missing prompt
curl -X POST http://localhost:8080/webhook/copilot \
  -H "Authorization: Bearer your_secret_token" \
  -H "Content-Type: application/json" \
  -d '{}'
# Response: {"success":false,"error":"Prompt is required","agent":"copilot"}
```

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

3. WEBHOOK_SECRET` | Webhook authentication token | `$(openssl rand -hex 32)` |
| `WEBHOOK_PORT` | Webhook server port | `8080` (default) |
| `Edit `entrypoint.sh` (add before SSH start):
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
| `GWebhook returns 401 Unauthorized?

Verify your `WEBHOOK_SECRET` matches:
```bash
# Check if secret is set
docker exec -it agent-cli env | grep WEBHOOK_SECRET

# Test with correct token
curl -X POST http://localhost:8080/webhook/copilot \
  -H "Authorization: Bearer YOUR_SECRET_HERE" \
  -H "Content-Type: application/json" \
  -d '{"prompt":"test"}'
```

### Webhook server not starting?

Check webhook server logs:
```bash
docker exec -it agent-cli cat /var/log/webhook-server.log
```

If `WEBHOOK_SECRET` is not set, the webhook server will not start (this is intentional).

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

### Webhook timeout errors?

Increase the timeout in your request payload:
```json
{
  "prompt": "complex task here",
  "timeout": 180
}
```

Maximum timeout is 300 seconds (5 minutes).ure the container is running:
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
