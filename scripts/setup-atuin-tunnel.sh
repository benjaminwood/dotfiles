#!/bin/bash
#
# Sets up a persistent SSH tunnel from localhost:8888 to desktop:8888
# so that devcontainers on this Mac can reach the Atuin sync server
# running on "desktop" (a Linux machine on the Tailscale network).
#
# The tunnel uses autossh to automatically reconnect on failure,
# and a launchd agent to start it on login.
#
# Prerequisites:
#   - Tailscale running, with "desktop" reachable
#   - Passwordless SSH to desktop (run: ssh-copy-id desktop)
#   - Homebrew installed
#
# Usage:
#   ./scripts/setup-atuin-tunnel.sh          # install and start
#   ./scripts/setup-atuin-tunnel.sh status   # check if running
#   ./scripts/setup-atuin-tunnel.sh stop     # stop and unload
#   ./scripts/setup-atuin-tunnel.sh uninstall # stop and remove plist

set -e

LABEL="com.benjaminwood.atuin-tunnel"
PLIST="$HOME/Library/LaunchAgents/${LABEL}.plist"
AUTOSSH=$(brew --prefix 2>/dev/null)/bin/autossh

case "${1:-install}" in
  status)
    if launchctl list "$LABEL" &>/dev/null; then
      echo "Tunnel is loaded."
      if nc -z localhost 8888 &>/dev/null; then
        echo "Port 8888 is open — tunnel is active."
      else
        echo "Port 8888 is not open — tunnel may be connecting."
      fi
    else
      echo "Tunnel is not loaded."
    fi
    exit 0
    ;;

  stop)
    echo "Stopping tunnel..."
    launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
    echo "Done."
    exit 0
    ;;

  uninstall)
    echo "Stopping and removing tunnel..."
    launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
    rm -f "$PLIST"
    echo "Removed $PLIST"
    exit 0
    ;;

  install)
    ;;

  *)
    echo "Usage: $0 {install|status|stop|uninstall}"
    exit 1
    ;;
esac

# Install autossh if not present
if ! command -v autossh &>/dev/null; then
  echo "Installing autossh..."
  brew install autossh
fi
AUTOSSH=$(which autossh)

# Verify we can reach desktop
echo "Verifying SSH to desktop..."
if ! ssh -o ConnectTimeout=5 -o BatchMode=yes desktop true 2>/dev/null; then
  echo "ERROR: Cannot SSH to desktop without a password."
  echo "Run: ssh-copy-id desktop"
  exit 1
fi
echo "SSH to desktop OK."

# Write launchd plist
echo "Writing $PLIST..."
cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>${LABEL}</string>
  <key>ProgramArguments</key>
  <array>
    <string>${AUTOSSH}</string>
    <string>-M</string>
    <string>0</string>
    <string>-N</string>
    <string>-o</string>
    <string>ServerAliveInterval=30</string>
    <string>-o</string>
    <string>ServerAliveCountMax=3</string>
    <string>-o</string>
    <string>ExitOnForwardFailure=yes</string>
    <string>-L</string>
    <string>8888:localhost:8888</string>
    <string>desktop</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <true/>
  <key>StandardErrorPath</key>
  <string>/tmp/atuin-tunnel.err.log</string>
  <key>StandardOutPath</key>
  <string>/tmp/atuin-tunnel.out.log</string>
</dict>
</plist>
EOF

# Load and start
echo "Loading tunnel..."
launchctl bootstrap "gui/$(id -u)" "$PLIST"

# Verify
sleep 2
if nc -z localhost 8888 &>/dev/null; then
  echo "Tunnel is active — localhost:8888 → desktop:8888"
else
  echo "Tunnel loaded but port 8888 not yet open. Check /tmp/atuin-tunnel.err.log"
fi
