# dotfiles

Personal dotfiles managed with [chezmoi](https://www.chezmoi.io/). Works across macOS, Linux desktop, and Docker containers.

## Quick start

### macOS

```bash
sh -c "$(curl -fsSL get.chezmoi.io)" -- init --apply benjaminwood
```

### Docker / Linux

```bash
git clone https://github.com/benjaminwood/dotfiles.git /tmp/dotfiles
bash /tmp/dotfiles/install.sh
```

`install.sh` bootstraps curl (apt/apk/yum/dnf), installs chezmoi, copies the source, and runs `chezmoi init --apply`.

## What's included

| Tool | macOS | Docker | Notes |
|---|---|---|---|
| zsh + oh-my-zsh | yes | yes | Default shell, Powerlevel10k theme |
| tmux | yes | yes | Nord theme, TPM plugins |
| fzf | yes | yes | Fuzzy finder, ctrl+r history |
| atuin | - | yes | Shell history sync, activated via `inith` |
| git config | yes | yes | Templated for name/email |
| Claude Code | - | yes | Auto-installed in containers |
| AeroSpace | yes | - | Tiling window manager |
| Karabiner | yes | - | Keyboard customization |
| i3 / i3status | - | linux desktop | Tiling WM for X11 |
| alacritty / termite | - | linux desktop | Terminal emulators |
| kubectl, helm, kubectx | brew | on-demand | `install-kube-tools` in Docker |

## Environment detection

Chezmoi auto-detects the environment via `/.dockerenv` or `/run/.containerenv`:

- **`is_docker`** - container (Docker, Podman, devcontainer)
- **`is_macos`** - macOS (Darwin)
- **`is_linux_desktop`** - Linux but not a container

See `.chezmoi.yaml.tmpl` for the full logic.

## Docker-specific setup

Containers get extra automation via chezmoi run scripts:

- System packages (git, zsh, tmux, iproute2, netcat) - supports apt, apk, yum, dnf
- Locale generation (Debian/Ubuntu)
- zsh as default shell
- fzf binary install
- atuin binary install (aarch64 + x86_64)
- Claude Code CLI
- TPM plugin install

### Atuin history sync

Atuin is installed but **not activated** until you run `inith`:

```bash
inith <password> <key> <hostname>
```

This logs into atuin, appends the activation to `~/.zshrc`, and enables ctrl+r history search. The sync address is auto-detected at `chezmoi apply` time (probes `host.docker.internal`, falls back to gateway IP).

On macOS, `scripts/setup-atuin-tunnel.sh` creates a persistent SSH tunnel to forward port 8888 from the atuin server.

### Kubernetes tools

Not installed by default. Run `install-kube-tools` (aliased in Docker) to install kubectl, helm, and kubectx/kubens on-demand.

## File structure

```
.chezmoi.yaml.tmpl          # Environment detection and template data
.chezmoiexternal.yaml       # External dependencies (oh-my-zsh, p10k, tpm, fzf)
.chezmoiignore              # Platform-conditional file exclusions
.chezmoiscripts/            # Auto-run install/setup scripts
bin/                        # Scripts deployed to ~/bin (Docker only)
dot_*                       # Dotfiles (deployed without dot_ prefix)
private_dot_config/         # ~/.config/* files
install.sh                  # Bootstrap entrypoint for containers
Brewfile                    # macOS Homebrew packages
scripts/                    # Manual helper scripts (not auto-run)
docker/                     # Dev container entrypoints
```

## License

MIT
