#!/bin/bash

sudo ()
{
    [[ $EUID = 0 ]] || set -- command sudo "$@"
    "$@"
}

SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
echo "system_install.sh ran at $(date) from $SCRIPT_DIR" >> $SCRIPT_DIR/install.log

echo "Installing packages" >> $SCRIPT_DIR/install.log

if [ `which apt` ]; then
  
  # Add source for RCM
  wget https://thoughtbot.com/thoughtbot.asc && \
    sudo apt-key add - < thoughtbot.asc && \
    echo "deb https://apt.thoughtbot.com/debian/ stable main" | sudo tee /etc/apt/sources.list.d/thoughtbot.list

  # Install RCM
  sudo apt-get update
  sudo apt-get install -o Dpkg::Options::="--force-confold" -yq rcm netcat-openbsd zsh iproute2

  # Install Kubectl
  curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
  sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

  # Install Helm
  curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

  # Install kubectx + kubens
  sudo git clone https://github.com/ahmetb/kubectx /opt/kubectx
  sudo ln -s /opt/kubectx/kubectx /usr/local/bin/kubectx
  sudo ln -s /opt/kubectx/kubens /usr/local/bin/kubens

elif [ `which apk` ]; then
   apk add tmux rcm zsh iproute2
elif [ `which yum` ]; then
  cd /etc/yum.repos.d/
  sudo curl -LO https://download.opensuse.org/repositories/utilities/15.5/utilities.repo

  cd ~

  sudo yum -y update && sudo yum -y install zsh rcm
else
   echo "UNKNOWN LINUX DISTRO"
   exit 1
fi
