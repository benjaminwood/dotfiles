#! /bin/bash
set -e

# Required for Docker-in-Docker
# /usr/local/share/docker-init.sh

# Setup named host entry (Like docker on Mac & Windows)
HOST_DOMAIN=host.docker.internal
HOST_IP=$(ip route | awk 'NR==1 {print $3}')
echo "$HOST_IP $HOST_DOMAIN" | sudo tee -a /etc/hosts > /dev/null

# Setup history in volume
ln -sfn /history/.node_repl_history ~/.node_repl_history

# Execute the original command
exec "$@"
