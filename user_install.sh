#!/bin/bash

SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
echo "user_install.sh ran at $(date) from $SCRIPT_DIR" >> $SCRIPT_DIR/install.log

echo "Installing fzf" >> $SCRIPT_DIR/install.log
# Install fzf from source
git clone --depth 1 --branch 0.20.0 https://github.com/junegunn/fzf.git ~/.fzf && \
  ~/.fzf/install --all

echo "Installing oh my zsh if it does not exist" >> $SCRIPT_DIR/install.log

# Install oh-my-zsh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
# Install Powerlevel10k theme
git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k

echo "Installing dotfiles with rcup" >> $SCRIPT_DIR/install.log

rcup -d $SCRIPT_DIR -f -B docker zshrc gitconfig gitignore p10k.zsh

echo "Installing solargraph" >> $SCRIPT_DIR/install.log
gem install solargraph
