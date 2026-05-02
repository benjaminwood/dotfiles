# vscode-tmux-env helper. Sourced by .zshrc (and .bashrc when present).
# Managed by chezmoi from benjaminwood/dotfiles. Do not edit by hand.
#
# Problem: VS Code injects VSCODE_* and REMOTE_CONTAINERS_* env vars into
# each integrated-terminal shell. The tmux server inherits whatever existed
# at first launch and strips most of it -- new panes (and panes after a VS
# Code reconnect with rotated IPC sockets) don't see current values. Inside
# tmux, `code .` hangs, and git operations requiring the VS Code credential
# helper fail.
#
# Fix:
#   - Outside tmux, with VS Code env present: snapshot relevant vars to
#     /tmp/vscode_env.<uid>.sh with POSIX single-quote escaping so JSON
#     values round-trip safely.
#   - Inside tmux ($TMUX is set): source that snapshot file. New panes pick
#     up the most recent VS Code session's env.
#
# Paired with `set -g update-environment` in tmux.conf so reattaching tmux
# from a new VS Code terminal also refreshes the server's session env
# (relevant for brand-new panes after reattach).

_vte_file="/tmp/vscode_env.$(id -u).sh"
# Array form works in both zsh (no SH_WORD_SPLIT by default) and bash.
_vte_vars=(VSCODE_IPC_HOOK_CLI VSCODE_GIT_IPC_HANDLE VSCODE_GIT_ASKPASS_NODE VSCODE_GIT_ASKPASS_MAIN VSCODE_GIT_ASKPASS_EXTRA_ARGS VSCODE_NONCE REMOTE_CONTAINERS_IPC REMOTE_CONTAINERS_SOCKETS REMOTE_CONTAINERS)

if [ -z "${TMUX:-}" ]; then
  if [ -n "${VSCODE_IPC_HOOK_CLI:-}" ] || [ -n "${REMOTE_CONTAINERS_IPC:-}" ]; then
    _vte_tmp="${_vte_file}.$$"
    ( umask 077 && : > "$_vte_tmp" )
    for _vte_v in "${_vte_vars[@]}"; do
      eval "_vte_val=\${$_vte_v-}"
      [ -z "$_vte_val" ] && continue
      # POSIX single-quote escape: ' -> '\''
      _vte_q=$(printf '%s' "$_vte_val" | sed "s/'/'\\\\''/g")
      printf "export %s='%s'\n" "$_vte_v" "$_vte_q" >> "$_vte_tmp"
    done
    mv "$_vte_tmp" "$_vte_file"
    unset _vte_tmp _vte_q _vte_val
  fi
else
  [ -r "$_vte_file" ] && . "$_vte_file"
fi

unset _vte_file _vte_vars _vte_v
