#!/usr/bin/env bash
# scripts/10-dev-stack.sh — Python, C/C++, Git, Node + Claude Code CLI.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${HERE}/lib.sh"
require_user "$@"

log "Developer stack: build tools, Python, C/C++, Node"
pac base-devel git gcc clang lld cmake ninja gdb make pkgconf \
    python python-pip python-pipx \
    nodejs npm

# pipx path
python -m pipx ensurepath >/dev/null 2>&1 || true

# npm global prefix in $HOME (no sudo for -g installs)
mkdir -p "$HOME/.npm-global"
npm config set prefix "$HOME/.npm-global" >/dev/null 2>&1 || true
export PATH="$HOME/.npm-global/bin:$PATH"

# Claude Code CLI
if ! have claude; then
  log "Installing Claude Code CLI (npm -g @anthropic-ai/claude-code)"
  npm install -g @anthropic-ai/claude-code || warn "Claude Code install failed (install later with: npm i -g @anthropic-ai/claude-code)"
else
  ok "Claude Code already installed"
fi

# A couple of quality-of-life Python tools via pipx (isolated)
for tool in ruff; do
  pipx list 2>/dev/null | grep -q "$tool" || pipx install "$tool" 2>/dev/null || true
done

# Git defaults (only set if unset — never clobber existing identity)
git config --global --get init.defaultBranch >/dev/null 2>&1 || git config --global init.defaultBranch main
git config --global --get pull.rebase        >/dev/null 2>&1 || git config --global pull.rebase false
if ! git config --global --get user.name >/dev/null 2>&1; then
  warn "Set your Git identity:  git config --global user.name 'Name'; git config --global user.email you@example.com"
fi

ok "Dev stack ready"
