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

# Self-update: if this script is running from a git clone, fast-forward to the
# latest main so subsequent dotfiles fixes propagate on each invocation. Safe
# on networks where GitHub is unreachable (--ff-only + || true).
if [ -d "$SCRIPT_DIR/.git" ] && command -v git &>/dev/null; then
  git -C "$SCRIPT_DIR" pull --ff-only --quiet 2>/dev/null || true
fi

# Self-heal: if chezmoi state exists but system-layer tools are missing
# (e.g. after a dev container rebuild where the persisted home volume keeps
# state but /etc/passwd and /usr/local/bin are reset to the image layer), nuke
# the state so run_once_ and run_onchange_ scripts re-execute. The scripts are
# already idempotent, so over-running is safe.
if [ -f "$HOME/.config/chezmoi/chezmoistate.boltdb" ]; then
  need_rerun=0
  for tool in atuin claude; do
    if ! [ -x "/usr/local/bin/$tool" ]; then
      need_rerun=1
      break
    fi
  done
  if [ "$need_rerun" = "1" ]; then
    echo "System-layer tools missing; resetting chezmoi state to force scripts to re-run."
    rm -f "$HOME/.config/chezmoi/chezmoistate.boltdb"
  fi
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
