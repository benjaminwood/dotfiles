#!/bin/bash

SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
echo "user_install.sh ran at $(date) from $SCRIPT_DIR" >> $SCRIPT_DIR/install.log

echo "Installing fzf" >> $SCRIPT_DIR/install.log
# Install fzf from source
git clone --depth 1 --branch 0.20.0 https://github.com/junegunn/fzf.git ~/.fzf && \
  ~/.fzf/install --all

echo "Installing atuin" >> $SCRIPT_DIR/install.log
ARCH=$(uname -m)
if [ "$ARCH" = "aarch64" ]; then
  echo "Detected aarch64 architecture, installing Atuin from binary" >> $SCRIPT_DIR/install.log
  LATEST_RELEASE=$(curl -L -s -H 'Accept: application/json' https://github.com/atuinsh/atuin/releases/latest)
  LATEST_VERSION=$(echo "$LATEST_RELEASE" | sed -e 's/.*"tag_name":"\([^"]*\)".*/\1/')
  ATUIN_BINARY_URL="https://github.com/atuinsh/atuin/releases/download/${LATEST_VERSION}/atuin-${LATEST_VERSION}-aarch64-unknown-linux-gnu.tar.gz"
  
  # Download and extract Atuin binary
  curl -L $ATUIN_BINARY_URL | sudo tar xz -C /tmp
  # Move the Atuin binary to /usr/local/bin
  sudo mv "/tmp/atuin-${LATEST_VERSION}-aarch64-unknown-linux-gnu/atuin" /usr/local/bin/
else
  if [ `which apt` ]; then
    bash <(curl --proto '=https' --tlsv1.2 -sSf https://setup.atuin.sh)
  fi
fi

echo "Installing oh my zsh if it does not exist" >> $SCRIPT_DIR/install.log

# Install oh-my-zsh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
# Install Powerlevel10k theme
git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k

echo "Installing dotfiles with rcup" >> $SCRIPT_DIR/install.log

if nc -vz host.docker.internal 8888 > /dev/null 2>&1; then
  ATUIN_HOST="host.docker.internal"
else
  ATUIN_HOST=$(ip route | awk 'NR==1 {print $3}')
fi

sed -i "s/<ATUIN_SYNC_SERVER>/$ATUIN_HOST/g" host-docker/config/atuin/config.toml
rcup -d $SCRIPT_DIR -f -B docker zshrc gitconfig gitignore p10k.zsh config/atuin/config.toml
