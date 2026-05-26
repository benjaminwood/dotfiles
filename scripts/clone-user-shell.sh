#!/usr/bin/env bash
# Clone ben's interactive shell config (oh-my-zsh, p10k, fzf, tmux) to
# another user. Used by container builds that need a second user with the
# same shell experience (e.g. agent personas).
#
# Usage (inside a Dockerfile, as root):
#   RUN clone-user-shell <target-user>
#
# Assumes:
#   - ben's home (/home/ben) already has chezmoi-applied dotfiles
#   - <target-user> already exists with home /home/<target-user>
#   - we are running as root (needs cp from /home/ben + chown)
set -euo pipefail

target="${1:?usage: clone-user-shell <target-user>}"

src="/home/ben"
dst="/home/$target"

if [ ! -d "$dst" ]; then
  echo "clone-user-shell: target home $dst does not exist" >&2
  exit 1
fi

# Interactive shell config bits. Each is copied verbatim if it exists.
# Deliberately NOT copied: .zsh_history (each user gets their own history),
# .gitconfig (each user has their own identity / credential helper),
# .ssh/, .gnupg/, .claude/ (secrets), .config/ (potentially per-user state).
for item in .oh-my-zsh .zshrc .p10k.zsh .fzf .fzf.zsh .tmux .tmux.conf; do
  if [ -e "$src/$item" ]; then
    cp -r "$src/$item" "$dst/$item"
  fi
done

# Retarget hardcoded /home/ben paths. fzf's install drops absolute paths
# into .fzf.zsh; other files use $HOME and don't need rewriting.
if [ -f "$dst/.fzf.zsh" ]; then
  sed -i "s|$src|$dst|g" "$dst/.fzf.zsh"
fi

chown -R "$target:$target" "$dst"

echo "clone-user-shell: replicated ben's shell config to $dst"
