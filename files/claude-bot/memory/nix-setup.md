---
type: workflow
tags: [nix, devenv, direnv, macos, home-manager, nix-darwin, dotfiles]
created: 2026-05-25
updated: 2026-05-26
---

# Nix Development Environment Setup

## Reproducible mac in 3 commands

```sh
xcode-select --install
sh <(curl -L https://nixos.org/nix/install) --daemon
git clone git@github.com:Pranavj17/dotfiles ~/dotfiles && cd ~/dotfiles && make install
```

The dotfiles repo (`~/dotfiles`, public at `Pranavj17/dotfiles`) is the source-of-truth. See [[dotfiles-repo]] note (in Claude Code's auto-memory) for full structure. Tagged `phase-1`, `phase-2`, `phase-3` after 2026-05-26 build-out.

## Layers

- **nix-darwin** (`system/*.nix`) — macOS defaults (dock, finder, fast key-repeat, screencapture dir), brew bundle (14 declared formulas: autojump, colima, docker, docker-compose, ffmpeg, gh, ghostscript, helm, imagemagick, k9s, kubernetes-cli, ollama, pandoc, poppler, watchman; 6 declared casks: alacritty, claude, google-chrome, maccy, tunnelblick, visual-studio-code), launchd agent for Echo daemon (com.claude-bot.daemon). `cleanup = "none"` — DO NOT change to "uninstall" until the declared list is exhaustive (see [[brew-bundle-cleanup-uninstall-pitfall]] in Claude Code's memory).
- **Home Manager standalone** (`home/*.nix`) — user-env: `programs.zsh` (with initContent from `files/zsh/functions.zsh`), `programs.starship.enable` (config via `xdg.configFile.lib.mkForce` to bypass HM's starship format-prettifier bug), `programs.direnv` (replaces manual hook), `home.packages` (bat, fzf, ripgrep, bun, nodejs_20, yarn, python311, awscli2, chamber, sops, terraform, terragrunt, kubectx, kubelogin-oidc, sshpass, meslo-lg).
- **Determinate Nix** — already-installed via flakehub. `system/default.nix` sets `nix.enable = false;` so nix-darwin doesn't fight with Determinate over `/nix`.

## Apply / verify

- `cd ~/dotfiles && make switch` runs BOTH `darwin-rebuild` (sudo) AND `home-manager switch`. `make test` runs `tests/smoke.sh` (flake check + 4 bin symlinks + 28-test shelltest + starship render + claude config symlinks + claude-bot launchd state).
- All current dotfiles are HM-managed symlinks into `/nix/store`. Editing the source file in `~/dotfiles/files/<...>` + `make switch` propagates.

## Shell & Terminal

- Terminal: Alacritty (TOML config preserved literally; HM symlinks the file rather than rendering — `\n` escape bytes are fragile). MesloLGS Nerd Font via brew. See [[alacritty-keybindings]].
- Prompt: Starship via `programs.starship.enable`. Custom `[custom.elixir]` block routes through `~/.local/bin/elixir-version-cached` (caches Elixir version string to disk — warm calls ~5ms instead of ~420ms cold-start).
- Plugins: zsh-autosuggestions + zsh-syntax-highlighting via `programs.zsh.{autosuggestion,syntaxHighlighting}.enable`.

## Per-project shells

`shell.nix` + `.envrc` (with `use nix`) per project. direnv loads the dev shell when you `cd` in. Elixir/Postgres/etc. provisioned per-project — NOT installed system-wide.

## Related

- [[alacritty-keybindings]] — terminal key mappings
- [[scripbox-repositories]] — uses Nix per-project
- [[secret-rotation-helpers]] — Keychain helpers + rotation
