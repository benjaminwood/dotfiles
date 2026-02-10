# CLAUDE.md

## Project overview

Personal dotfiles managed with chezmoi. Supports macOS, Linux desktop, and Docker containers. The chezmoi source directory is this repo root.

## Key concepts

- **Chezmoi naming**: `dot_` prefix becomes `.`, `private_` sets 0600 permissions, `executable_` sets +x, `.tmpl` suffix enables Go template rendering
- **Environment detection**: `.chezmoi.yaml.tmpl` sets `is_docker`, `is_macos`, `is_linux_desktop` based on presence of `/.dockerenv`
- **Docker = base config**: Docker containers use the same config as macOS (no special docker branches in config files)
- **Atuin is opt-in**: Not activated until user runs `inith`. The `eval "$(atuin init zsh ...)"` line is appended to `~/.zshrc` by `inith`, not present in the managed template

## File layout

- `.chezmoi.yaml.tmpl` - Template data and environment detection
- `.chezmoiexternal.yaml` - External deps (oh-my-zsh, p10k, tpm, fzf)
- `.chezmoiignore` - Conditional ignores per environment
- `.chezmoiscripts/run_once_*` - Run once on first apply (atuin, claude, zsh default)
- `.chezmoiscripts/run_onchange_*` - Re-run when source hash changes (packages, fzf, tpm)
- `bin/executable_*` - Scripts deployed to `~/bin/` with +x (docker only, excluded via `.chezmoiignore`)
- `install.sh` - Bootstrap entrypoint: installs curl (multi-PM), chezmoi, copies source, applies

## Testing changes

```bash
# Local test (arm64 Ubuntu)
docker run -d --name dotfiles-test ubuntu:24.04 sleep infinity
docker cp . dotfiles-test:/tmp/dotfiles
docker exec dotfiles-test bash /tmp/dotfiles/install.sh
docker exec -it dotfiles-test zsh

# Remote test (x86_64)
ssh ben@desktop "docker run -d --name dotfiles-test ubuntu:24.04 sleep infinity"
# clone branch on host, docker cp in, exec install.sh

# Cleanup
docker rm -f dotfiles-test
```

## Common tasks

- **Add a new dotfile**: Create `dot_filename` (or `dot_filename.tmpl` if templated) in repo root
- **Add a docker-only file**: Put it in `bin/` or add to `.chezmoiignore` with `{{- if not .is_docker }}` guard
- **Add a new package**: For macOS add to `Brewfile`, for Docker add to `run_onchange_install-packages-linux.sh.tmpl`
- **Add an external dependency**: Add entry to `.chezmoiexternal.yaml`

## Gotchas

- `run_once_` scripts use chezmoi's state DB to track execution. Delete `~/.config/chezmoi/chezmoistate.boltdb` to re-run them
- The atuin install script (`run_once_install-atuin.sh.tmpl`) downloads arch-specific binaries to `/usr/local/bin/`, not `~/.atuin/bin/`
- Package install script supports apt, apk, yum, and dnf but locale generation is guarded to only run on Debian/Ubuntu
- `install.sh` is listed in `.chezmoiignore` so it's not deployed to `$HOME`
