#!/bin/bash
set -e

echo "==================================================="
echo "Agent CLI Tools Container Starting..."
echo "==================================================="

# Fix permissions for home directory (in case volume ownership is wrong)
chown -R agent:agent /home/agent 2>/dev/null || true

# ===========================================
# 1. DYNAMIC TOOL INSTALLATION
# ===========================================
if [ ! -z "$INSTALL_PACKAGES" ]; then
    echo ""
    echo "Checking requested packages: $INSTALL_PACKAGES"
    echo "---------------------------------------------------"
    
    # Install NPM packages
    for pkg in $INSTALL_PACKAGES; do
        # Skip if it looks like a pip package (contains / or starts with common pip patterns)
        if [[ "$pkg" == *"/"* ]] || [[ "$pkg" == @* ]] || [[ "$pkg" == *"-cli" ]]; then
            # This looks like an npm package
            if ! sudo -u agent NPM_CONFIG_PREFIX=/home/agent/.npm-global npm list -g "$pkg" > /dev/null 2>&1; then
                echo "📦 Installing NPM package: $pkg..."
                sudo -u agent NPM_CONFIG_PREFIX=/home/agent/.npm-global npm install -g "$pkg" --loglevel=error
            else
                echo "✅ NPM package already installed: $pkg"
            fi
        fi
    done
fi

# Install Python packages if specified
if [ ! -z "$INSTALL_PIP_PACKAGES" ]; then
    echo ""
    echo "Checking requested Python packages: $INSTALL_PIP_PACKAGES"
    echo "---------------------------------------------------"
    
    for pkg in $INSTALL_PIP_PACKAGES; do
        if ! sudo -u agent pip3 list 2>/dev/null | grep -i "^${pkg} " > /dev/null; then
            echo "🐍 Installing Python package: $pkg..."
            sudo -u agent pip3 install --user "$pkg" --quiet
        else
            echo "✅ Python package already installed: $pkg"
        fi
    done
fi

# ===========================================
# 2. OPTIONAL UPDATE CHECK
# ===========================================
if [ "$CHECK_UPDATES" = "true" ]; then
    echo ""
    echo "Checking for package updates..."
    echo "---------------------------------------------------"
    sudo -u agent NPM_CONFIG_PREFIX=/home/agent/.npm-global npm update -g 2>/dev/null || true
    sudo -u agent pip3 install --user --upgrade pip 2>/dev/null || true
fi

# ===========================================
# 3. DYNAMIC MCP CONFIGURATION
# ===========================================
echo ""
echo "Configuring Model Context Protocol (MCP) servers..."
echo "---------------------------------------------------"

# Create config directories for both Copilot and Claude
COPILOT_CONFIG_DIR="/home/agent/.config/github-copilot"
CLAUDE_CONFIG_DIR="/home/agent/.config/claude-code"

mkdir -p "$COPILOT_CONFIG_DIR" "$CLAUDE_CONFIG_DIR"

# Build MCP configuration
MCP_CONFIG_PATH="$COPILOT_CONFIG_DIR/mcp-config.json"
CLAUDE_MCP_CONFIG_PATH="$CLAUDE_CONFIG_DIR/mcp-config.json"

# Start JSON object
echo '{' > /tmp/mcp_config.json
echo '  "mcpServers": {' >> /tmp/mcp_config.json

# Loop through env vars starting with MCP_ and ending with _URL
# Example: MCP_FILESYSTEM_URL=http://mcp-fs:8000/sse -> "filesystem": { "url": "...", "transport": "sse" }
config_added=false
while IFS= read -r line; do
    key=$(echo "$line" | cut -d= -f1)
    url=$(echo "$line" | cut -d= -f2-)
    
    # Extract name: MCP_MYSERVER_URL -> myserver
    name=$(echo "$key" | sed 's/^MCP_//;s/_URL$//' | tr '[:upper:]' '[:lower:]' | tr '_' '-')
    
    if [ "$config_added" = true ]; then
        echo "," >> /tmp/mcp_config.json
    fi
    
    echo "    \"$name\": {" >> /tmp/mcp_config.json
    echo "      \"url\": \"$url\"," >> /tmp/mcp_config.json
    echo "      \"transport\": \"sse\"" >> /tmp/mcp_config.json
    echo -n "    }" >> /tmp/mcp_config.json
    
    config_added=true
    echo "🔗 MCP Server configured: $name -> $url"
done < <(printenv | grep -E '^MCP_.*_URL=')

# Close JSON
echo "" >> /tmp/mcp_config.json
echo '  }' >> /tmp/mcp_config.json
echo '}' >> /tmp/mcp_config.json

# Move to final locations if we found any configs
if [ "$config_added" = true ]; then
    cp /tmp/mcp_config.json "$MCP_CONFIG_PATH"
    cp /tmp/mcp_config.json "$CLAUDE_MCP_CONFIG_PATH"
    chown agent:agent "$MCP_CONFIG_PATH" "$CLAUDE_MCP_CONFIG_PATH"
    echo "✅ MCP configuration saved"
else
    echo "ℹ️  No MCP servers configured (no MCP_*_URL environment variables found)"
fi

# ===========================================
# 4. SSH SETUP
# ===========================================
echo ""
echo "Setting up SSH access..."
echo "---------------------------------------------------"

# Ensure .ssh directory exists
if [ ! -d "/home/agent/.ssh" ]; then
    mkdir -p /home/agent/.ssh
    chmod 700 /home/agent/.ssh
    chown agent:agent /home/agent/.ssh
fi

# If authorized_keys is mounted, ensure correct permissions
if [ -f "/home/agent/.ssh/authorized_keys" ]; then
    chmod 600 /home/agent/.ssh/authorized_keys
    chown agent:agent /home/agent/.ssh/authorized_keys
    echo "✅ SSH authorized_keys configured"
fi

# ===========================================
# 5. DISPLAY AUTHENTICATION STATUS
# ===========================================
echo ""
echo "==================================================="
echo "Container Ready!"
echo "==================================================="
echo ""
echo "Authentication Status:"
echo "---------------------------------------------------"

# Check GitHub CLI auth
if sudo -u agent gh auth status > /dev/null 2>&1; then
    echo "✅ GitHub CLI: Authenticated"
else
    echo "⚠️  GitHub CLI: Not authenticated"
    echo "   Run: ssh agent@localhost -p 2222"
    echo "   Then: gh auth login"
fi

# Check Anthropic API key
if [ ! -z "$ANTHROPIC_API_KEY" ]; then
    echo "✅ Anthropic API Key: Configured via environment"
elif [ -f "/home/agent/.anthropic/credentials" ]; then
    echo "✅ Anthropic: Authenticated"
else
    echo "⚠️  Anthropic: Not configured"
    echo "   Set ANTHROPIC_API_KEY environment variable or run claude login"
fi

echo ""
echo "SSH Access:"
echo "   ssh agent@localhost -p 2222"
echo "   (SSH key required - mount your public key to /home/agent/.ssh/authorized_keys)"
echo ""
echo "==================================================="

# Start SSH Daemon (the main process)
exec "$@"
