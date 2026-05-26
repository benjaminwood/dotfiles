FROM node:22-trixie

ENV DOCKER_BUILDKIT=1

RUN apt-get update

ARG INSTALL_ZSH="true"
ARG USER="ben"
ARG UID="1000"

# node:22-trixie ships the `node` user at uid 1000. Free that uid so the
# common-utils feature below can honor UID=1000 for ben instead of falling back
# to 1001 (which forces every downstream consumer to swap UIDs back to match
# the host's user). Renumber node out of the way; nothing in the image needs
# the node user account anyway.
RUN usermod -u 9999 node && groupmod -g 9999 node

# Install common utils (zsh, oh-my-zsh, user setup)
# install.sh execs into main.sh which needs scripts/ and bin/ siblings,
# so we download the full feature directory first (mirrors devcontainer CLI behavior)
RUN mkdir -p /tmp/common-utils && \
    curl -fsSL https://github.com/devcontainers/features/archive/main.tar.gz | \
    tar xz --strip-components=3 -C /tmp/common-utils features-main/src/common-utils && \
    cd /tmp/common-utils && \
    INSTALLZSH="${INSTALL_ZSH}" USERNAME="${USER}" USERUID="${UID}" USERGID="${UID}" UPGRADEPACKAGES="true" \
    bash install.sh && \
    rm -rf /tmp/common-utils
# Install Docker-in-Docker (moby not available on Debian Trixie)
# RUN MOBY="false" bash -c "$(curl -fsSL "https://raw.githubusercontent.com/devcontainers/features/main/src/docker-in-docker/install.sh")"
# Install GitHub CLI
RUN bash -c "$(curl -fsSL "https://raw.githubusercontent.com/devcontainers/features/main/src/github-cli/install.sh")"
# Install nvm, pnpm, yarn (version=none skips installing a second Node)
RUN mkdir -p /tmp/node-feature && \
    curl -fsSL https://github.com/devcontainers/features/archive/main.tar.gz | \
    tar xz --strip-components=3 -C /tmp/node-feature features-main/src/node && \
    cd /tmp/node-feature && \
    VERSION="none" USERNAME="${USER}" \
    bash install.sh && \
    rm -rf /tmp/node-feature

# Configure npm global install path with group permissions
ARG NPM_GLOBAL=/usr/local/share/npm-global
ENV PATH=${NPM_GLOBAL}/bin:${PATH}
RUN if ! cat /etc/group | grep -e "^npm:" > /dev/null 2>&1; then groupadd -r npm; fi \
    && usermod -a -G npm ${USER} \
    && umask 0002 \
    && mkdir -p ${NPM_GLOBAL} \
    && touch /usr/local/etc/npmrc \
    && chown ${USER}:npm ${NPM_GLOBAL} /usr/local/etc/npmrc \
    && chmod g+s ${NPM_GLOBAL} \
    && npm config -g set prefix ${NPM_GLOBAL} \
    && su ${USER} -c "npm config -g set prefix ${NPM_GLOBAL}" \
    # Install TypeScript and eslint globally
    && su ${USER} -c "umask 0002 && npm install -g typescript eslint" \
    && npm cache clean --force > /dev/null 2>&1

# Init persistent .zsh_history
ENV HISTFILE=/history/.zsh_history
RUN mkdir -p /history && chown $USER:$USER /history

COPY docker/node/entrypoint.sh /usr/local/share/entrypoint.sh

# Helper for derived images that add a second user account (e.g. agent personas)
# and want them to share ben's interactive shell setup. Invoked as root:
#   RUN clone-user-shell <target-user>
COPY scripts/clone-user-shell.sh /usr/local/bin/clone-user-shell
RUN chmod 0755 /usr/local/bin/clone-user-shell

USER $USER

# Install and apply dotfiles via install.sh (installs chezmoi, copies source, applies)
COPY ./ /home/$USER/dotfiles
# /.dockerenv doesn't exist during build (only at runtime), but chezmoi needs it for detection
RUN sudo touch /.dockerenv && bash ~/dotfiles/install.sh && sudo rm -rf ~/dotfiles

ENTRYPOINT ["/usr/local/share/entrypoint.sh"]
CMD ["sleep", "infinity"]
