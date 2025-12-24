# .bashrc for agent user

# Add NPM global packages to PATH
export NPM_CONFIG_PREFIX=/home/agent/.npm-global
export PATH=$PATH:/home/agent/.npm-global/bin

# Add Python user packages to PATH
export PATH=$PATH:/home/agent/.local/bin

# Source system bashrc if it exists
if [ -f /etc/bash.bashrc ]; then
    . /etc/bash.bashrc
fi

# Enable bash completion for gh
if command -v gh >/dev/null 2>&1; then
    eval "$(gh completion -s bash)"
fi

# Colorful prompt
export PS1='\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '

# Common aliases
alias ll='ls -lah'
alias la='ls -A'
alias l='ls -CF'
