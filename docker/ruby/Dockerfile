FROM ruby:3.0.2

ENV DOCKER_BUILDKIT=1

RUN apt-get update

ARG INSTALL_ZSH="true"
ARG USER="ben"
ARG UID="1000"

# Download script and run it with the option above
RUN bash -c "$(curl -fsSL "https://raw.githubusercontent.com/microsoft/vscode-dev-containers/main/script-library/common-debian.sh")" -- "${INSTALL_ZSH}" "${USER}" "${UID}" "${UID}" "true" "true"
RUN bash -c "$(curl -fsSL "https://raw.githubusercontent.com/microsoft/vscode-dev-containers/main/script-library/docker-debian.sh")"
RUN bash -c "$(curl -fsSL "https://raw.githubusercontent.com/microsoft/vscode-dev-containers/main/script-library/github-debian.sh")"

# Init persistent .zsh_history
ENV HISTFILE=/history/.zsh_history
RUN mkdir -p /history && chown $USER:$USER /history

USER $USER

COPY ./ /home/$USER/dotfiles
RUN sudo cp /home/$USER/dotfiles/docker/ruby/entrypoint.sh /usr/local/share/entrypoint.sh

RUN sudo /home/$USER/dotfiles/system_install.sh
RUN /home/$USER/dotfiles/user_install.sh

ENV SHELL=/home/$USER/.vscode_shell

RUN sudo apt-get clean -y && sudo rm -rf /var/lib/apt/lists/*

ENTRYPOINT ["/usr/local/share/entrypoint.sh"]
CMD ["sleep", "infinity"]