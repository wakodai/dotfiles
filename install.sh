#!/bin/bash
# VS Code devcontainer dotfiles install script
# This script is called by VS Code's dotfiles feature after cloning the repo.

set -eu

# Install chezmoi if not present
if ! command -v chezmoi &>/dev/null; then
    sh -c "$(curl -fsLS get.chezmoi.io)" -- -b "$HOME/.local/bin"
    export PATH="$HOME/.local/bin:$PATH"
fi

# Apply dotfiles using chezmoi
# --source points to the cloned dotfiles repo (the current directory)
chezmoi init --source="$(pwd)" --apply

# Ensure ~/.local/bin is in PATH
if ! grep -q 'HOME/.local/bin' "$HOME/.bashrc" 2>/dev/null; then
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
fi
export PATH="$HOME/.local/bin:$PATH"

# Install Claude Code CLI if not present
if ! command -v claude &>/dev/null; then
    curl -fsSL https://claude.ai/install.sh | bash
fi
