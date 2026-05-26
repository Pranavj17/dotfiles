# Spec — Home Manager + nix-darwin bootstrap for `Pranavj17/dotfiles`

**Date:** 2026-05-26 · **Status:** approved (verbal "lgtm"), pending user review of this file

## Context

A new-laptop migration on 2026-05-25 surfaced the fact that ~all our shell/terminal/Claude-tooling work lives only on local disk:
`~/.zshrc`, `~/.config/starship.toml`, `~/.config/alacritty/alacritty.toml`, `~/.claude/statusline-command.sh` + `~/.claude/statusline/*.sh`,
`~/.config/shell-tests/*.sh`, `~/.local/bin/{har-extract, claude-export-split, elixir-version-cached}`, `~/.claude/settings.json`,
`~/Library/LaunchAgents/com.claude-bot.daemon.plist`, and macOS system defaults. None of it is in any git repo. A second laptop swap (or any
disk failure) would erase the entire setup — exactly the failure mode this spec eliminates.

We use Nix as our day-to-day toolchain (Determinate Nix + direnv + shell.nix per project). The industry-standard answer for our stack is
**Home Manager + nix-darwin via flakes** — it's the only option that gives bit-for-bit reproducibility *and* fits the existing Nix workflow.
Decision is locked: full mac scope, rolled out in three phases.

## Goals

- **A fresh mac reaches our working environment in three commands**: `xcode-select --install`, install Nix, `nix run nix-darwin -- switch --flake ~/dotfiles#$(hostname)`.
- **Every file currently floating in `$HOME` is tracked** in `Pranavj17/dotfiles` (public repo, no secrets — see secrets section).
- **Backup goal achieved at end of Phase 1** (one evening). Phases 2 and 3 are additive; we can stop at any phase and still have something working.
- **No regression** of any currently working behaviour (statusline, secret helpers, `shelltest`, etc.).

## Non-goals

- Multi-machine differentiation via templates / chezmoi-style conditionals — single mac for now.
- Encrypted-secrets-in-repo (sops-nix / agenix). Keychain stays the source of truth (we already shipped `secret get|set|rm` for this).
- CI on GitHub for `darwin-rebuild` checks — macOS runners are flaky and we don't gain much; local `make test` suffices.
- Migrating VS Code / Cursor / Neovim configs — not in current scope.

## Architecture

### Repo layout (`~/dotfiles/`)

```
~/dotfiles/
├── flake.nix              # inputs: nixpkgs, home-manager, nix-darwin
├── flake.lock             # pinned versions — the reproducibility guarantee
├── Makefile               # interface: install / switch / test / update (defined below)
├── README.md
├── docs/specs/            # this file lives here
├── system/                # nix-darwin (mac-level)        — Phase 2
│   ├── default.nix        # darwinConfigurations.<hostname>
│   ├── defaults.nix       # macOS defaults (Dock, Finder, key-repeat, screenshot dir…)
│   ├── homebrew.nix       # declarative brew bundle for casks/GUI apps
│   ├── launchd.nix        # services — com.claude-bot.daemon, etc.
│   └── packages.nix       # system pkgs
├── home/                  # home-manager (user-level)     — Phase 1 onwards
│   ├── default.nix        # homeConfigurations.<user>
│   ├── packages.nix       # user pkgs (jq, bun, ripgrep, gh, bat, kubectx, kubelogin, sshpass, starship…)
│   ├── shell.nix          # programs.zsh.* — Phase 1: initExtra from out-of-store; Phase 3: native
│   ├── starship.nix       # Phase 1: symlink; Phase 3: programs.starship.settings
│   ├── alacritty.nix      # Phase 1: symlink (kept symlinked even at Phase 3 — TOML escape-sensitivity)
│   └── files.nix          # out-of-store symlinks for everything else
├── files/                 # literal source-of-truth files (Phase 1)
│   ├── starship.toml
│   ├── alacritty.toml
│   ├── claude/            # settings.json, keybindings.json, statusline-command.sh, statusline/*, curated MEMORY.md + notes
│   ├── claude-bot/        # CLAUDE.md (Echo's prompt), .mcp.json, memory/<curated>.md
│   ├── shell-tests/       # secret.sh, run.sh
│   └── bin/               # har-extract, claude-export-split, elixir-version-cached
└── tests/
    └── smoke.sh           # post-switch verification
```

### Claude configuration inventory (what counts as "dotfiles" for our setup)

The Claude tooling is deeper than just `settings.json` — it's the bulk of the failure-mode-on-laptop-swap we're protecting against. Explicit in / out lists below; only `files/claude/` and `files/claude-bot/` carry these into the repo.

**Tracked — `files/claude/`:**
- `settings.json` — global Claude Code settings (hooks, enabled plugins, statusLine command, theme, autoCompact).
- `keybindings.json` — Claude Code key bindings.
- `statusline-command.sh` + `statusline/*.sh` — the renderer and helpers (`probe-mini`, `probe-import`, `probe-triage`, `gen-greeter`, `gen-slot`, `test.sh`).
- `projects/-Users-pranav-j-Documents-memory/memory/MEMORY.md` + the curated `*.md` notes (e.g. `dev-env-nix-toolchain`, `secrets-keychain-preference`, `nested-claude-headless-sandbox`, `apps-repo-clean-build`, etc.). The auto-generated `auto-*.md` session dumps are **explicitly excluded** — they're activity logs, not config.

**Tracked — `files/claude-bot/`:**
- `CLAUDE.md` — Echo's instructions / identity.
- `.mcp.json` — Echo's MCP server config.
- `memory/` — the curated memory notes (e.g. `echo-personality.md`, `pranav-profile.md`, `pranav-claude-insights.md`, `alacritty-keybindings.md`, `nix-setup.md`, `scripbox-repositories.md`, `vpn-setup.md`, `secret-rotation-helpers.md`). Auto-rotated `auto-*.md` dumps are excluded.

**Tracked elsewhere in the repo:**
- `files/bin/` — `har-extract`, `claude-export-split`, `elixir-version-cached`.
- `files/shell-tests/` — `secret.sh`, `run.sh`.
- `system/launchd.nix` (Phase 2) — declares `com.claude-bot.daemon` (replaces the hand-managed `~/Library/LaunchAgents/` plist).

**Explicitly NOT tracked (caches, state, transcripts):**
- `~/.claude/plugins/` (~163 MB plugin cache), `~/.claude/projects/*.jsonl` (session transcripts, ~86 MB), `~/.claude/{cache,image-cache,paste-cache,file-history,session-env,sessions,shell-snapshots,tasks,telemetry,usage-data,backups,chrome}/`, `~/.claude/{history.jsonl,.last-cleanup,mcp-needs-auth-cache.json}`.
- `~/.claude-bot/{logs,processes,crons,.remember}/`, `~/.claude-bot/{daemon.pid,session-id}`.
- All `auto-*.md` files under both `memory/` directories — these regenerate on every session.

A `files/claude/.gitignore` (and `files/claude-bot/.gitignore`) enforces the exclusions with explicit patterns (`auto-*.md`, `*.jsonl`, `plugins/`, etc.) so the repo can't accumulate caches by accident.

### Phase 1 — Bootstrap (single evening; backup-achieved)

- `flake.nix` with `home-manager` as the only meaningful input (nix-darwin added in Phase 2).
- For every current dotfile, `home.file."<dest>".source = ./files/<file>` — literal files, untouched, just symlinked from `/nix/store/…` into `$HOME`. **No Nix-syntax rewrites in this phase.**
- Move current files into `files/` via `git mv` after the symlinks are in place (careful sequencing — symlink first, then remove original, never simultaneous).
- `home-manager switch --flake .` should produce a `$HOME` indistinguishable from today's.
- Push to GitHub (public repo). The laptop-swap problem is solved at end of Phase 1.

### Phase 2 — nix-darwin (system reproducibility)

- Add `nix-darwin` as flake input; wire `system/` as `darwinConfigurations.<hostname>`.
- `defaults.nix`: macOS UI/dev defaults — fast key-repeat, screenshot dir, Finder show extensions, Dock auto-hide, etc.
- `homebrew.nix`: brew bundle for casks — Google Chrome, Alacritty, Tunnelblick, Claude (desktop), Cursor, Determinate Nix, Docker.
- `launchd.nix`: `launchd.user.agents.claude-bot` declares the bun-run daemon (`RunAtLoad=true`, `KeepAlive=true`) — the existing `~/Library/LaunchAgents/com.claude-bot.daemon.plist` is retired.
- `darwin-rebuild switch --flake .` → whole mac reproducible.

### Phase 3 — Refactor high-value configs to native HM modules

- `programs.zsh.enable = true` + `programs.zsh.initExtra = ''…''` — extract `secret`, `rotate_metabase`, `rotate_graylog`, `metabase_token`, `metabase_password`, `metabase_lead_id` as Nix strings. zsh-autosuggestions and zsh-syntax-highlighting come through `programs.zsh.plugins`.
- `programs.starship` with `settings = { … elixir.disabled = true; custom.elixir = { command = "${pkgs.…}/bin/elixir-version-cached"; … }; }` — typed Nix instead of free-form TOML.
- `programs.git`, `programs.direnv`, `programs.fzf` where modules add value.
- `alacritty.toml` stays out-of-store (the keybindings contain `\n` escapes that previously got mangled by Edit/Write — kept-as-text is safer).

## Secrets strategy

- **macOS Keychain remains the only place secrets live.** No new encrypted-blob system.
- `secret get|set|rm <name>` (already in `~/.zshrc`) is the universal accessor.
- Where Nix needs a secret at runtime, interpolate via `secret get` in the shell command (e.g., `programs.zsh.sessionVariables.GRAYLOG_API_TOKEN = "$(secret get GRAYLOG_API_TOKEN)"` becomes a sourced-line in `initExtra`, not a build-time value).
- Repo is public; nothing secret is ever committed.

## Makefile interface

| Target | What it does |
|---|---|
| `make install` | First-time bootstrap on a new machine: install Nix (if absent), then run `darwin-rebuild switch --flake .#$(hostname)`. Idempotent. |
| `make switch` | Apply the current flake: `darwin-rebuild switch --flake .#$(hostname)` then `make test`. The day-to-day verb. |
| `make test` | Run `tests/smoke.sh` (see below). |
| `make update` | `nix flake update` (refresh `flake.lock`) then `make switch`. The deliberate-upgrade verb. |

## Testing

- `tests/smoke.sh` runs after every `switch`:
  - `nix flake check` (the flake itself is well-formed)
  - `bash ~/.config/shell-tests/run.sh` (statusline + secret helper tests — 28 assertions)
  - `~/.local/bin/elixir-version-cached >/dev/null` (cache mechanism is intact)
  - `starship prompt --terminal-width=120 >/dev/null` (prompt renders)
- `make test` runs the smoke script.
- `make switch` = `darwin-rebuild switch --flake .#$(hostname)` followed by `make test`.

## Bootstrap on a fresh mac (the promise)

```sh
xcode-select --install
sh <(curl -L https://nixos.org/nix/install) --daemon
git clone git@github.com:Pranavj17/dotfiles ~/dotfiles && cd ~/dotfiles
nix run nix-darwin -- switch --flake .#$(hostname)
```

## Risks

- **Phase 1 symlink sequencing** — if we move a file to `files/` before the symlink is in place, the running shell loses access. Mitigate by symlinking first via HM switch, then removing the original.
- **nix-darwin launchd module** for `claude-bot` must reproduce the existing plist (KeepAlive, EnvironmentVariables with the long Nix-bin PATH). Smoke test verifies the daemon is running post-switch.
- **Public repo + accidental secrets** — pre-commit hook will grep for likely secrets (long base64 strings, `eyJ…` JWTs, `xoxb-…` Slack tokens, etc.) and refuse commit. Defence-in-depth on top of the Keychain discipline.
- **Channel drift** — flake inputs pin nixpkgs to a commit. Upgrades are deliberate via `nix flake update`. The pin is the feature.

## Open questions

- Decide hostname-based or shared `darwinConfigurations` once we have multiple machines. Single-host for now.
- Choose whether to bring `~/.config/git/config` under HM in Phase 3 (currently no global gitconfig customisations beyond defaults).

## References

- [Davis Haupt — Managing dotfiles on macOS with Nix](https://davi.sh/blog/2024/02/nix-home-manager/) (2024)
- [Brandon Rundquist — Nix on macOS: flakes, Home Manager, nix-darwin, overlays](https://bswr.io/notes/dotfiles_nix/) (2025)
- [Home Manager Manual](https://nix-community.github.io/home-manager/)
- [chezmoi comparison table](https://www.chezmoi.io/comparison-table/) (for the rejected alternative)
