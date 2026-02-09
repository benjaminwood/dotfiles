FROM ruby:4.0.1

ENV DOCKER_BUILDKIT=1

RUN apt-get update

ARG INSTALL_ZSH="true"
ARG USER="ben"
ARG UID="1000"

# Install common utils (zsh, oh-my-zsh, user setup)
RUN INSTALLZSH="${INSTALL_ZSH}" USERNAME="${USER}" UID="${UID}" GID="${UID}" UPGRADEPACKAGES="true" \
    bash -c "$(curl -fsSL "https://raw.githubusercontent.com/devcontainers/features/main/src/common-utils/install.sh")"
# Install Docker-in-Docker
RUN bash -c "$(curl -fsSL "https://raw.githubusercontent.com/devcontainers/features/main/src/docker-in-docker/install.sh")"
# Install GitHub CLI
RUN bash -c "$(curl -fsSL "https://raw.githubusercontent.com/devcontainers/features/main/src/github-cli/install.sh")"

# Init persistent .zsh_history
ENV HISTFILE=/history/.zsh_history
RUN mkdir -p /history && chown $USER:$USER /history

USER $USER

COPY ./ /home/$USER/dotfiles
RUN sudo cp /home/$USER/dotfiles/docker/ruby/entrypoint.sh /usr/local/share/entrypoint.sh

RUN sudo /home/$USER/dotfiles/system_install.sh
RUN /home/$USER/dotfiles/user_install.sh

RUN sudo apt-get clean -y && sudo rm -rf /var/lib/apt/lists/*

ENTRYPOINT ["/usr/local/share/entrypoint.sh"]
CMD ["sleep", "infinity"]
