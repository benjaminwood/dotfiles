#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"

# Bootstrap: install curl if missing (needed for chezmoi install)
if ! command -v curl &>/dev/null; then
  echo "Installing curl..."
  if [ "$(id -u)" -eq 0 ]; then SUDO=""; else SUDO="sudo"; fi
  if command -v apt-get &>/dev/null; then
    $SUDO apt-get update -qq && $SUDO apt-get install -yq curl
  elif command -v apk &>/dev/null; then
    $SUDO apk add --no-cache curl
  elif command -v yum &>/dev/null; then
    $SUDO yum install -y curl
  elif command -v dnf &>/dev/null; then
    $SUDO dnf install -y curl
  fi
fi

# Install chezmoi if not present
if ! command -v chezmoi &>/dev/null; then
  echo "Installing chezmoi..."
  sh -c "$(curl -fsSL get.chezmoi.io)" -- -b "$HOME/.local/bin"
  export PATH="$HOME/.local/bin:$PATH"
fi

# Copy source to chezmoi's default location if not already there
CHEZMOI_SOURCE="$HOME/.local/share/chezmoi"
if [ "$SCRIPT_DIR" != "$CHEZMOI_SOURCE" ]; then
  mkdir -p "$(dirname "$CHEZMOI_SOURCE")"
  rm -rf "$CHEZMOI_SOURCE"
  cp -a "$SCRIPT_DIR" "$CHEZMOI_SOURCE"
fi

# Apply dotfiles
chezmoi init --apply --force
