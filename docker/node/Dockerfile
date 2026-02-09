FROM node:22

ENV DOCKER_BUILDKIT=1

RUN apt-get update

ARG INSTALL_ZSH="true"
ARG USER="ben"
ARG UID="1000"

# Install common utils (zsh, oh-my-zsh, user setup)
# install.sh execs into main.sh which needs scripts/ and bin/ siblings,
# so we download the full feature directory first (mirrors devcontainer CLI behavior)
RUN mkdir -p /tmp/common-utils && \
    curl -fsSL https://github.com/devcontainers/features/archive/main.tar.gz | \
    tar xz --strip-components=3 -C /tmp/common-utils features-main/src/common-utils && \
    cd /tmp/common-utils && \
    INSTALLZSH="${INSTALL_ZSH}" USERNAME="${USER}" UID="${UID}" GID="${UID}" UPGRADEPACKAGES="true" \
    bash install.sh && \
    rm -rf /tmp/common-utils
# Install Docker-in-Docker (moby not available on Debian Trixie)
# RUN MOBY="false" bash -c "$(curl -fsSL "https://raw.githubusercontent.com/devcontainers/features/main/src/docker-in-docker/install.sh")"
# Install GitHub CLI
RUN bash -c "$(curl -fsSL "https://raw.githubusercontent.com/devcontainers/features/main/src/github-cli/install.sh")"

# Init persistent .zsh_history
ENV HISTFILE=/history/.zsh_history
RUN mkdir -p /history && chown $USER:$USER /history

USER $USER

COPY ./ /home/$USER/dotfiles
RUN sudo cp /home/$USER/dotfiles/docker/node/entrypoint.sh /usr/local/share/entrypoint.sh

RUN sudo /home/$USER/dotfiles/system_install.sh
RUN /home/$USER/dotfiles/user_install.sh

RUN sudo apt-get clean -y && sudo rm -rf /var/lib/apt/lists/*

ENTRYPOINT ["/usr/local/share/entrypoint.sh"]
CMD ["sleep", "infinity"]
