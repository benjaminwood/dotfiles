#!/bin/bash

# Add source for RCM
wget https://thoughtbot.com/thoughtbot.asc && \
  sudo apt-key add - < thoughtbot.asc && \
  echo "deb https://apt.thoughtbot.com/debian/ stable main" | sudo tee /etc/apt/sources.list.d/thoughtbot.list

echo "Installing apt things" >> ~/install.log
# Install RCM
sudo apt-get update
sudo apt-get install -o Dpkg::Options::="--force-confold" -yq rcm netcat zsh

echo "Installing tmux from source" >> ~/install.log
# Build tmux from source
TMUX_VERSION=3.2a && \
  wget https://github.com/tmux/tmux/releases/download/$TMUX_VERSION/tmux-$TMUX_VERSION.tar.gz && \
  tar xf tmux-$TMUX_VERSION.tar.gz && \
  rm -f tmux-$TMUX_VERSION.tar.gz && \
  cd tmux-$TMUX_VERSION && \
  ./configure && \
  make && \
  sudo make install && \
  cd - && \
  sudo rm -rf /usr/local/src/tmux-\* && \
  sudo mv tmux-$TMUX_VERSION /usr/local/src