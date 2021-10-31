#!/bin/bash

SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

echo "Installing fzf" >> ~/install.log
# Install fzf from source
git clone --depth 1 --branch 0.20.0 https://github.com/junegunn/fzf.git ~/.fzf && \
  ~/.fzf/install --all

echo "Installing oh my zsh if it does not exist" >> ~/install.log
# Install oh-my-zsh
[ ! -d "/home/$USER/.oh-my-zsh" ] && sh -c "$(wget -O- https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh)" "" --unattended

echo "Installing dotfiles with rcup" >> ~/install.log

rcup -d $SCRIPT_DIR -f -B docker vscode_shell tmux.conf zshrc gitconfig gitignore

echo "Installing solargraph" >> ~/install.log
gem install solargraph