Update the dev container Docker images in this repo to align with upstream.

## Architecture

This repo builds two dev container Docker images via a GitHub Actions matrix in `.github/workflows/build.yml`:

| Variant | Dockerfile | Base image | GHCR image |
|---------|-----------|------------|------------|
| Ruby | `docker/ruby/Dockerfile` | `ruby:<version>` | `ghcr.io/benjaminwood/ben-dev-env-ruby` |
| Node | `docker/node/Dockerfile` | `node:<version>` | `ghcr.io/benjaminwood/ben-dev-env-node` |

Each image has a matching `docker/<variant>/entrypoint.sh` for runtime init (host entry, history symlinks).

## How the images are built

Both Dockerfiles follow the same pattern, installing devcontainer features manually (not via the devcontainer CLI) by downloading the feature source from the devcontainers/features repo and running install.sh:

1. **common-utils** — Zsh, Oh My Zsh, non-root user `ben` (UID 1000), upgraded OS packages, CLI tools
2. **github-cli** — `gh` CLI
3. **(Node only) node feature** — nvm, pnpm, yarn via `VERSION="none"` (uses the base image's Node, not a second install)
4. **(Node only) npm global setup** — `/usr/local/share/npm-global` with npm group + setgid, then `npm install -g typescript eslint`
5. Dotfiles — copies the repo in, runs `system_install.sh` and `user_install.sh`

## Upstream references to check

The images are modeled after the official Microsoft devcontainer images. When updating, check these sources for changes:

- **devcontainers/features repo** (common-utils, github-cli, node, docker-in-docker):
  https://github.com/devcontainers/features/tree/main/src
  - `src/common-utils/install.sh` — check for new env vars, changed behavior
  - `src/github-cli/install.sh` — check for new options
  - `src/node/install.sh` — check for new env vars (VERSION, USERNAME, etc.)
  - `src/docker-in-docker/install.sh` — currently commented out due to moby/Trixie issues, check if resolved

- **devcontainers/images repo** (the pre-built images we model after):
  https://github.com/devcontainers/images/tree/main/src
  - `src/ruby/.devcontainer/Dockerfile` and `devcontainer.json` — Ruby variant reference
  - `src/javascript-node/.devcontainer/Dockerfile` and `devcontainer.json` — Node parent image reference
  - `src/typescript-node/.devcontainer/Dockerfile` and `devcontainer.json` — TypeScript layer reference

- **Docker Hub base images**:
  - https://hub.docker.com/_/ruby — check latest stable Ruby version
  - https://hub.docker.com/_/node — check latest LTS Node version

## Update procedure

1. Read all files in `docker/ruby/` and `docker/node/` and `.github/workflows/build.yml`
2. Fetch the upstream references above to check for:
   - New base image versions (Ruby, Node)
   - Changes to devcontainer feature install scripts (new env vars, new dependencies, breaking changes)
   - New global packages or tools in the MS typescript-node or ruby images
   - Security fixes or CVE patches applied upstream
3. Propose updates to the Dockerfiles, entrypoints, and workflow as needed
4. Keep both variants structurally consistent — they should mirror each other except for language-specific bits
5. Do NOT switch to using the devcontainer CLI or devcontainer.json — we install features manually via their install.sh scripts
