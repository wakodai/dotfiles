#!/bin/bash
# VS Code devcontainer dotfiles install script
# This script is called by VS Code's dotfiles feature after cloning the repo.

set -eu

# Install chezmoi if not present
if ! command -v chezmoi &>/dev/null; then
    sh -c "$(curl -fsLS get.chezmoi.io)" -- -b /usr/local/bin
fi

# Apply dotfiles using chezmoi
# --source points to the cloned dotfiles repo (the current directory)
chezmoi init --source="$(pwd)" --apply
