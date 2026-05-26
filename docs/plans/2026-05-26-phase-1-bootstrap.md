# Phase 1 — Home Manager bootstrap (out-of-store symlinks) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bring the entire current macOS dev environment (`~/.zshrc`, `~/.config/starship.toml`, `~/.config/alacritty/alacritty.toml`, `~/.claude/*`, `~/.claude-bot/*`, `~/.local/bin/*`, `~/.config/shell-tests/*`) under Home Manager via a flake, with **literal files** (no Nix rewrites). At the end of Phase 1, `~/dotfiles/` is a complete, pushable backup; a `home-manager switch --flake .` reproduces the user environment bit-for-bit.

**Architecture:** Flake-based `home-manager` standalone (no `nix-darwin` yet — that's Phase 2). Every current dotfile is moved into `~/dotfiles/files/<...>` and declared as `home.file.<path>.source = ./files/<...>` in `home/files.nix`, which creates a `/nix/store`-symlink in `$HOME`. No file content is rewritten as Nix. Scripts get `executable = true`. Each migration is its own commit so individual reverts are surgical.

**Tech Stack:** Nix flakes, Home Manager (`nix-community/home-manager`), zsh, Starship, Alacritty. Apple Silicon (`aarch64-darwin`).

**Migration risk order:** scripts → small configs → big configs → `.zshrc` last (it's load-bearing for every shell). Smoke test runs after every switch.

---

## File Structure (locked in by this plan)

Created in `~/dotfiles/`:

| Path | Purpose |
|---|---|
| `flake.nix`, `flake.lock` | Flake inputs (`nixpkgs`, `home-manager`); locked versions |
| `home/default.nix` | `homeConfigurations."pranav.j"` entry point |
| `home/files.nix` | `home.file.<dest>.source = ./files/<src>` for every tracked file |
| `home/packages.nix` | Phase 1 user packages (just `bat` for now; more in Phase 3) |
| `Makefile` | `install` / `switch` / `test` / `update` targets |
| `tests/smoke.sh` | Post-switch verification (shelltest + prompt sanity) |
| `files/zshrc` | literal `~/.zshrc` |
| `files/starship/starship.toml` | literal `~/.config/starship.toml` |
| `files/alacritty/alacritty.toml` | literal `~/.config/alacritty/alacritty.toml` |
| `files/claude/{settings.json,keybindings.json,statusline-command.sh,statusline/*.sh}` | Claude Code config + statusline |
| `files/claude/projects-memory/MEMORY.md` + `<curated>.md` | curated auto-memory notes (no `auto-*.md`) |
| `files/claude-bot/{CLAUDE.md,.mcp.json,memory/<curated>.md}` | Echo daemon prompt + curated memories |
| `files/bin/{har-extract,claude-export-split,elixir-version-cached}` | personal scripts |
| `files/shell-tests/{secret.sh,run.sh}` | helper tests |
| `files/claude/.gitignore` + `files/claude-bot/.gitignore` | exclude `auto-*.md`, plugins/, transcripts |
| `.githooks/pre-commit` | scan for likely secrets before allowing commit |

Files like `home/{shell,starship,alacritty}.nix` are *not* created in Phase 1 — those are Phase 3 (native modules).

---

## Task 1: Bootstrap flake with home-manager + a canary

**Files:**
- Create: `~/dotfiles/flake.nix`
- Create: `~/dotfiles/home/default.nix`
- Create: `~/dotfiles/home/files.nix`
- Create: `~/dotfiles/home/packages.nix`
- Create: `~/dotfiles/files/canary.txt`

Canary proves HM activation works before any real file is at risk.

- [ ] **Step 1: Write `flake.nix`**

```nix
{
  description = "Pranav's dotfiles — Home Manager (Phase 1 bootstrap)";

  inputs = {
    nixpkgs.url      = "github:NixOS/nixpkgs/nixpkgs-unstable";
    home-manager = {
      url            = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, home-manager, ... }:
    let
      system = "aarch64-darwin";
      pkgs   = import nixpkgs { inherit system; };
    in {
      homeConfigurations."pranav.j" = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        modules = [ ./home/default.nix ];
      };
    };
}
```

- [ ] **Step 2: Write `home/default.nix`**

```nix
{ pkgs, ... }: {
  imports = [ ./files.nix ./packages.nix ];

  home.username      = "pranav.j";
  home.homeDirectory = "/Users/pranav.j";
  home.stateVersion  = "24.11";  # do not change after first switch

  programs.home-manager.enable = true;
}
```

- [ ] **Step 3: Write `home/files.nix` with just the canary**

```nix
{ ... }: {
  home.file."dotfiles-canary.txt".source = ../files/canary.txt;
}
```

- [ ] **Step 4: Write `home/packages.nix` (empty for now)**

```nix
{ pkgs, ... }: {
  home.packages = [ ];
}
```

- [ ] **Step 5: Write `files/canary.txt`**

```text
This file is managed by Home Manager (Phase 1).
Delete this entry from home/files.nix once you trust the setup.
```

- [ ] **Step 6: Activate**

Run:
```bash
cd ~/dotfiles
nix run home-manager/release-24.11 -- switch --flake .#pranav.j
```
Expected: ends with `Activation finished successfully`. A symlink `~/dotfiles-canary.txt` now points into `/nix/store/...`.

Verify:
```bash
test -L ~/dotfiles-canary.txt && readlink ~/dotfiles-canary.txt | grep -q /nix/store && echo "canary OK"
```
Expected: `canary OK`.

- [ ] **Step 7: Commit**

```bash
cd ~/dotfiles
git add flake.nix flake.lock home/ files/canary.txt
git commit -m "phase-1: bootstrap flake with home-manager + canary file"
```

---

## Task 2: Makefile interface

**Files:**
- Create: `~/dotfiles/Makefile`

- [ ] **Step 1: Write the Makefile**

```make
.PHONY: install switch test update help
USER := pranav.j
# HOST := $(shell hostname -s)   # added in Phase 2 when darwinConfigurations are keyed by hostname

help:
	@echo "make install   - first-time bootstrap on a new machine"
	@echo "make switch    - apply current flake to user env (+ run tests)"
	@echo "make test      - run smoke tests (without switching)"
	@echo "make update    - bump flake inputs and switch"

install:
	@command -v nix >/dev/null || (echo "Install Nix first: sh <(curl -L https://nixos.org/nix/install) --daemon" && exit 1)
	nix run home-manager/release-24.11 -- switch --flake .#$(USER)
	$(MAKE) test

switch:
	nix run home-manager/release-24.11 -- switch --flake .#$(USER)
	$(MAKE) test

test:
	bash tests/smoke.sh

update:
	nix flake update
	$(MAKE) switch
```

- [ ] **Step 2: Verify `make help` works**

Run: `cd ~/dotfiles && make help`
Expected: prints the four target descriptions.

- [ ] **Step 3: Commit**

```bash
git add Makefile
git commit -m "phase-1: add Makefile (install/switch/test/update)"
```

---

## Task 3: Smoke test (initial)

**Files:**
- Create: `~/dotfiles/tests/smoke.sh`

The smoke test grows as features are added; initial version checks the flake itself.

- [ ] **Step 1: Write `tests/smoke.sh`**

```bash
#!/usr/bin/env bash
# Post-switch verification for Phase 1.
# Each block can fail independently; we collect failures and exit non-zero at the end.
set -u
fail=0
ok()  { printf '  ok  %s\n' "$1"; }
bad() { printf 'FAIL  %s\n' "$1"; fail=1; }

echo "== flake check =="
( cd "$(dirname "$0")/.." && nix flake check --no-build 2>/dev/null ) && ok "nix flake check" || bad "nix flake check"

# More blocks appended in later tasks (shelltest, starship prompt, har-extract, etc.)

echo
[ "$fail" -eq 0 ] && echo "✅ smoke PASSED" || echo "❌ smoke FAILED"
exit "$fail"
```

- [ ] **Step 2: chmod + run**

```bash
chmod +x ~/dotfiles/tests/smoke.sh
cd ~/dotfiles && make test
```
Expected: `ok  nix flake check` and `✅ smoke PASSED`, exit 0.

- [ ] **Step 3: Commit**

```bash
git add tests/smoke.sh
git commit -m "phase-1: add tests/smoke.sh (initial: nix flake check)"
```

---

## Task 4: Migrate `~/.local/bin/*` scripts (lowest risk first)

**Files:**
- Create: `~/dotfiles/files/bin/har-extract` (copy of `~/.local/bin/har-extract`)
- Create: `~/dotfiles/files/bin/claude-export-split` (copy of `~/.local/bin/claude-export-split`)
- Create: `~/dotfiles/files/bin/elixir-version-cached` (copy of `~/.local/bin/elixir-version-cached`)
- Modify: `~/dotfiles/home/files.nix`

- [ ] **Step 1: Copy scripts into repo**

```bash
mkdir -p ~/dotfiles/files/bin
cp -p ~/.local/bin/har-extract            ~/dotfiles/files/bin/
cp -p ~/.local/bin/claude-export-split    ~/dotfiles/files/bin/
cp -p ~/.local/bin/elixir-version-cached  ~/dotfiles/files/bin/
diff ~/.local/bin/har-extract ~/dotfiles/files/bin/har-extract && echo "har-extract identical"
diff ~/.local/bin/claude-export-split ~/dotfiles/files/bin/claude-export-split && echo "claude-export-split identical"
diff ~/.local/bin/elixir-version-cached ~/dotfiles/files/bin/elixir-version-cached && echo "elixir-version-cached identical"
```
Expected: three "identical" lines, no diff output.

- [ ] **Step 2: Declare in `home/files.nix`** (replace the canary)

```nix
{ ... }: {
  home.file = {
    ".local/bin/har-extract"           = { source = ../files/bin/har-extract;           executable = true; };
    ".local/bin/claude-export-split"   = { source = ../files/bin/claude-export-split;   executable = true; };
    ".local/bin/elixir-version-cached" = { source = ../files/bin/elixir-version-cached; executable = true; };
  };
}
```

- [ ] **Step 3: Remove originals so HM can place its symlinks**

HM refuses to overwrite existing regular files. Remove the originals first; we have copies in `files/bin/`.

```bash
rm ~/.local/bin/har-extract ~/.local/bin/claude-export-split ~/.local/bin/elixir-version-cached
```

- [ ] **Step 4: Switch + verify**

```bash
cd ~/dotfiles && make switch
```
Expected: `Activation finished successfully`.

```bash
test -L ~/.local/bin/har-extract            && echo "har-extract            symlinked"
test -L ~/.local/bin/claude-export-split    && echo "claude-export-split    symlinked"
test -L ~/.local/bin/elixir-version-cached  && echo "elixir-version-cached  symlinked"
~/.local/bin/elixir-version-cached >/dev/null && echo "elixir-version-cached executes"
```
Expected: four success lines.

- [ ] **Step 5: Extend smoke test with bin checks**

Append to `tests/smoke.sh` before the final summary:
```bash
echo "== ~/.local/bin scripts =="
for s in har-extract claude-export-split elixir-version-cached; do
  [ -L "$HOME/.local/bin/$s" ] && [ -x "$HOME/.local/bin/$s" ] && ok "$s symlink+exec" || bad "$s symlink+exec"
done
```

Run `make test` — should still PASS.

- [ ] **Step 6: Commit**

```bash
git add files/bin/ home/files.nix tests/smoke.sh
git commit -m "phase-1: track ~/.local/bin scripts (har-extract, claude-export-split, elixir-version-cached)"
```

---

## Task 5: Migrate `~/.config/shell-tests/*`

**Files:**
- Create: `~/dotfiles/files/shell-tests/secret.sh`
- Create: `~/dotfiles/files/shell-tests/run.sh`
- Modify: `~/dotfiles/home/files.nix`
- Modify: `~/dotfiles/tests/smoke.sh`

- [ ] **Step 1: Copy files**

```bash
mkdir -p ~/dotfiles/files/shell-tests
cp -p ~/.config/shell-tests/secret.sh ~/dotfiles/files/shell-tests/
cp -p ~/.config/shell-tests/run.sh    ~/dotfiles/files/shell-tests/
diff ~/.config/shell-tests/secret.sh ~/dotfiles/files/shell-tests/secret.sh && echo "secret.sh identical"
diff ~/.config/shell-tests/run.sh    ~/dotfiles/files/shell-tests/run.sh    && echo "run.sh identical"
```

- [ ] **Step 2: Add to `home/files.nix`** (merge into the existing `home.file = { … }` block)

```nix
".config/shell-tests/secret.sh" = { source = ../files/shell-tests/secret.sh; executable = true; };
".config/shell-tests/run.sh"    = { source = ../files/shell-tests/run.sh;    executable = true; };
```

- [ ] **Step 3: Remove originals + switch + verify**

```bash
rm ~/.config/shell-tests/secret.sh ~/.config/shell-tests/run.sh
cd ~/dotfiles && make switch
test -L ~/.config/shell-tests/run.sh && echo "run.sh symlinked"
bash ~/.config/shell-tests/run.sh   # the full 28-test suite
```
Expected: `ALL SHELL TESTS PASSED`.

- [ ] **Step 4: Add shelltest to smoke**

Append to `tests/smoke.sh` (before the final summary):
```bash
echo "== shelltest (statusline + secret helper) =="
bash "$HOME/.config/shell-tests/run.sh" >/dev/null && ok "shelltest 28/28" || bad "shelltest 28/28"
```

Run `make test` — should still PASS.

- [ ] **Step 5: Commit**

```bash
git add files/shell-tests/ home/files.nix tests/smoke.sh
git commit -m "phase-1: track ~/.config/shell-tests/{secret,run}.sh"
```

---

## Task 6: Migrate `~/.config/starship.toml`

**Files:**
- Create: `~/dotfiles/files/starship/starship.toml`
- Modify: `~/dotfiles/home/files.nix`
- Modify: `~/dotfiles/tests/smoke.sh`

- [ ] **Step 1: Copy**

```bash
mkdir -p ~/dotfiles/files/starship
cp -p ~/.config/starship.toml ~/dotfiles/files/starship/
diff ~/.config/starship.toml ~/dotfiles/files/starship/starship.toml && echo "starship.toml identical"
```

- [ ] **Step 2: Add to `home/files.nix`**

```nix
".config/starship.toml".source = ../files/starship/starship.toml;
```

- [ ] **Step 3: Remove original + switch + verify**

```bash
rm ~/.config/starship.toml
cd ~/dotfiles && make switch
test -L ~/.config/starship.toml && echo "starship.toml symlinked"
cd ~/Documents/memory && starship prompt --terminal-width=120 >/dev/null && echo "starship renders"
```

- [ ] **Step 4: Extend smoke**

```bash
echo "== starship prompt renders =="
( cd "$HOME" && starship prompt --terminal-width=120 >/dev/null ) && ok "starship prompt" || bad "starship prompt"
```

`make test` should still PASS.

- [ ] **Step 5: Commit**

```bash
git add files/starship/ home/files.nix tests/smoke.sh
git commit -m "phase-1: track ~/.config/starship.toml"
```

---

## Task 7: Migrate `~/.config/alacritty/alacritty.toml`

**Files:**
- Create: `~/dotfiles/files/alacritty/alacritty.toml`
- Modify: `~/dotfiles/home/files.nix`

The TOML contains `\n` escapes that previously got mangled by Edit/Write — `cp` preserves them byte-for-byte, so this is safe.

- [ ] **Step 1: Copy + verify byte equality**

```bash
mkdir -p ~/dotfiles/files/alacritty
cp -p ~/.config/alacritty/alacritty.toml ~/dotfiles/files/alacritty/
shasum ~/.config/alacritty/alacritty.toml ~/dotfiles/files/alacritty/alacritty.toml
```
Expected: the two SHAs identical.

- [ ] **Step 2: Add to `home/files.nix`**

```nix
".config/alacritty/alacritty.toml".source = ../files/alacritty/alacritty.toml;
```

- [ ] **Step 3: Remove original + switch + verify**

```bash
rm ~/.config/alacritty/alacritty.toml
cd ~/dotfiles && make switch
test -L ~/.config/alacritty/alacritty.toml && echo "alacritty.toml symlinked"
shasum ~/.config/alacritty/alacritty.toml ~/dotfiles/files/alacritty/alacritty.toml
```
Expected: SHAs match (the symlink resolves to the same bytes).

- [ ] **Step 4: Commit**

```bash
git add files/alacritty/ home/files.nix
git commit -m "phase-1: track ~/.config/alacritty/alacritty.toml"
```

---

## Task 8: Migrate `~/.claude/` (Code config + statusline)

**Files:**
- Create: `~/dotfiles/files/claude/settings.json`
- Create: `~/dotfiles/files/claude/keybindings.json`
- Create: `~/dotfiles/files/claude/statusline-command.sh`
- Create: `~/dotfiles/files/claude/statusline/{probe-mini,probe-import,probe-triage,gen-greeter,gen-slot,test}.sh`
- Modify: `~/dotfiles/home/files.nix`
- Modify: `~/dotfiles/tests/smoke.sh`

- [ ] **Step 1: Copy**

```bash
mkdir -p ~/dotfiles/files/claude/statusline
cp -p ~/.claude/settings.json            ~/dotfiles/files/claude/
cp -p ~/.claude/keybindings.json         ~/dotfiles/files/claude/
cp -p ~/.claude/statusline-command.sh    ~/dotfiles/files/claude/
for f in probe-mini.sh probe-import.sh probe-triage.sh gen-greeter.sh gen-slot.sh test.sh; do
  cp -p ~/.claude/statusline/$f ~/dotfiles/files/claude/statusline/
done
for f in settings.json keybindings.json statusline-command.sh statusline/probe-mini.sh statusline/probe-import.sh statusline/probe-triage.sh statusline/gen-greeter.sh statusline/gen-slot.sh statusline/test.sh; do
  diff ~/.claude/$f ~/dotfiles/files/claude/$f && echo "$f identical"
done
```
Expected: 9 "identical" lines.

- [ ] **Step 2: Add to `home/files.nix`** (merge)

```nix
".claude/settings.json".source                  = ../files/claude/settings.json;
".claude/keybindings.json".source               = ../files/claude/keybindings.json;
".claude/statusline-command.sh"                 = { source = ../files/claude/statusline-command.sh;            executable = true; };
".claude/statusline/probe-mini.sh"              = { source = ../files/claude/statusline/probe-mini.sh;         executable = true; };
".claude/statusline/probe-import.sh"            = { source = ../files/claude/statusline/probe-import.sh;       executable = true; };
".claude/statusline/probe-triage.sh"            = { source = ../files/claude/statusline/probe-triage.sh;       executable = true; };
".claude/statusline/gen-greeter.sh"             = { source = ../files/claude/statusline/gen-greeter.sh;        executable = true; };
".claude/statusline/gen-slot.sh"                = { source = ../files/claude/statusline/gen-slot.sh;           executable = true; };
".claude/statusline/test.sh"                    = { source = ../files/claude/statusline/test.sh;               executable = true; };
```

- [ ] **Step 3: Remove originals + switch + verify**

```bash
rm ~/.claude/settings.json ~/.claude/keybindings.json ~/.claude/statusline-command.sh
rm -rf ~/.claude/statusline   # the directory and its contents (we copied them)
cd ~/dotfiles && make switch
test -L ~/.claude/settings.json          && echo "settings.json     symlinked"
test -L ~/.claude/statusline-command.sh  && echo "statusline-cmd    symlinked"
test -L ~/.claude/statusline/test.sh     && echo "statusline/test   symlinked"
bash ~/.claude/statusline/test.sh        # 23 statusline assertions
```
Expected: 3 symlinked lines + `23 passed, 0 failed`.

- [ ] **Step 4: Extend smoke**

```bash
echo "== claude config files symlinked =="
for f in settings.json keybindings.json statusline-command.sh statusline/test.sh; do
  [ -L "$HOME/.claude/$f" ] && ok ".claude/$f" || bad ".claude/$f"
done
```

`make test` should still PASS (28 + claude-symlink checks).

- [ ] **Step 5: Commit**

```bash
git add files/claude/settings.json files/claude/keybindings.json files/claude/statusline-command.sh files/claude/statusline/ home/files.nix tests/smoke.sh
git commit -m "phase-1: track ~/.claude/{settings,keybindings,statusline*}"
```

---

## Task 9: Migrate curated auto-memory under `~/.claude/projects/.../memory/`

**Files:**
- Create: `~/dotfiles/files/claude/projects-memory/MEMORY.md`
- Create: `~/dotfiles/files/claude/projects-memory/<curated>.md` (one per file below)
- Create: `~/dotfiles/files/claude/.gitignore`
- Modify: `~/dotfiles/home/files.nix`

**Curated list (DO NOT include `auto-*.md` — they regenerate every session):**
`MEMORY.md`, `dev-env-nix-toolchain.md`, `milky-way-repo.md`, `nix-npx-broken-prefix.md`, `apps-repo-clean-build.md`, `kubelogin-port-8000-chroma-collision.md`, `alacritty-toml-escapes.md`, `claude-bot-plugin-bun.md`, `scripbox-vpn-endpoint.md`, `metabase-lead-id-lookup.md`, `nested-claude-headless-sandbox.md`, `secrets-keychain-preference.md`.

- [ ] **Step 1: Copy curated files**

```bash
SRC=~/.claude/projects/-Users-pranav-j-Documents-memory/memory
DST=~/dotfiles/files/claude/projects-memory
mkdir -p "$DST"
cp -p "$SRC/MEMORY.md" "$DST/"
for f in dev-env-nix-toolchain milky-way-repo nix-npx-broken-prefix apps-repo-clean-build \
         kubelogin-port-8000-chroma-collision alacritty-toml-escapes claude-bot-plugin-bun \
         scripbox-vpn-endpoint metabase-lead-id-lookup nested-claude-headless-sandbox \
         secrets-keychain-preference; do
  cp -p "$SRC/$f.md" "$DST/"
done
ls "$DST"
```
Expected: 12 files listed (`MEMORY.md` + 11 notes).

- [ ] **Step 2: Add ignore patterns** at `~/dotfiles/files/claude/.gitignore`

```
# Per-session auto-memory dumps — regenerated every session, do not track
auto-*.md

# Claude Code internal state — never tracked
plugins/
projects/*.jsonl
cache/
image-cache/
paste-cache/
file-history/
session-env/
sessions/
shell-snapshots/
tasks/
telemetry/
usage-data/
backups/
chrome/
history.jsonl
.last-cleanup
mcp-needs-auth-cache.json
```

- [ ] **Step 3: Add to `home/files.nix`**

Inside `home.file`, declare each file (HM doesn't support globs for `home.file` keys — each path is explicit; long but unambiguous):
```nix
".claude/projects/-Users-pranav-j-Documents-memory/memory/MEMORY.md".source                                = ../files/claude/projects-memory/MEMORY.md;
".claude/projects/-Users-pranav-j-Documents-memory/memory/dev-env-nix-toolchain.md".source                = ../files/claude/projects-memory/dev-env-nix-toolchain.md;
".claude/projects/-Users-pranav-j-Documents-memory/memory/milky-way-repo.md".source                       = ../files/claude/projects-memory/milky-way-repo.md;
".claude/projects/-Users-pranav-j-Documents-memory/memory/nix-npx-broken-prefix.md".source                = ../files/claude/projects-memory/nix-npx-broken-prefix.md;
".claude/projects/-Users-pranav-j-Documents-memory/memory/apps-repo-clean-build.md".source                = ../files/claude/projects-memory/apps-repo-clean-build.md;
".claude/projects/-Users-pranav-j-Documents-memory/memory/kubelogin-port-8000-chroma-collision.md".source = ../files/claude/projects-memory/kubelogin-port-8000-chroma-collision.md;
".claude/projects/-Users-pranav-j-Documents-memory/memory/alacritty-toml-escapes.md".source               = ../files/claude/projects-memory/alacritty-toml-escapes.md;
".claude/projects/-Users-pranav-j-Documents-memory/memory/claude-bot-plugin-bun.md".source                = ../files/claude/projects-memory/claude-bot-plugin-bun.md;
".claude/projects/-Users-pranav-j-Documents-memory/memory/scripbox-vpn-endpoint.md".source                = ../files/claude/projects-memory/scripbox-vpn-endpoint.md;
".claude/projects/-Users-pranav-j-Documents-memory/memory/metabase-lead-id-lookup.md".source              = ../files/claude/projects-memory/metabase-lead-id-lookup.md;
".claude/projects/-Users-pranav-j-Documents-memory/memory/nested-claude-headless-sandbox.md".source       = ../files/claude/projects-memory/nested-claude-headless-sandbox.md;
".claude/projects/-Users-pranav-j-Documents-memory/memory/secrets-keychain-preference.md".source          = ../files/claude/projects-memory/secrets-keychain-preference.md;
```

- [ ] **Step 4: Remove originals + switch**

```bash
SRC=~/.claude/projects/-Users-pranav-j-Documents-memory/memory
for f in MEMORY dev-env-nix-toolchain milky-way-repo nix-npx-broken-prefix apps-repo-clean-build \
         kubelogin-port-8000-chroma-collision alacritty-toml-escapes claude-bot-plugin-bun \
         scripbox-vpn-endpoint metabase-lead-id-lookup nested-claude-headless-sandbox \
         secrets-keychain-preference; do
  rm -f "$SRC/$f.md"
done
cd ~/dotfiles && make switch
test -L "$HOME/.claude/projects/-Users-pranav-j-Documents-memory/memory/MEMORY.md" && echo "MEMORY.md symlinked"
```

- [ ] **Step 5: Commit**

```bash
git add files/claude/projects-memory/ files/claude/.gitignore home/files.nix
git commit -m "phase-1: track curated auto-memory (MEMORY.md + 11 notes); ignore auto-*.md and caches"
```

---

## Task 10: Migrate `~/.claude-bot/` (Echo's prompt + curated memories)

**Files:**
- Create: `~/dotfiles/files/claude-bot/CLAUDE.md`
- Create: `~/dotfiles/files/claude-bot/.mcp.json`
- Create: `~/dotfiles/files/claude-bot/memory/{echo-personality,pranav-profile,pranav-claude-insights,alacritty-keybindings,nix-setup,scripbox-repositories,vpn-setup,secret-rotation-helpers}.md`
- Create: `~/dotfiles/files/claude-bot/.gitignore`
- Modify: `~/dotfiles/home/files.nix`

- [ ] **Step 1: Copy**

```bash
SRC=~/.claude-bot
DST=~/dotfiles/files/claude-bot
mkdir -p "$DST/memory"
cp -p "$SRC/CLAUDE.md"     "$DST/"
cp -p "$SRC/.mcp.json"     "$DST/"
for f in echo-personality pranav-profile pranav-claude-insights alacritty-keybindings \
         nix-setup scripbox-repositories vpn-setup secret-rotation-helpers; do
  cp -p "$SRC/memory/$f.md" "$DST/memory/"
done
ls "$DST" "$DST/memory"
```
Expected: `CLAUDE.md`, `.mcp.json` in `claude-bot/`; 8 `.md` files in `claude-bot/memory/`.

- [ ] **Step 2: Add `files/claude-bot/.gitignore`**

```
# Per-session auto memory dumps — regenerated every session
memory/auto-*.md

# Runtime state — never tracked
logs/
processes/
crons/
.remember/
daemon.pid
session-id
.claude/         # nested claude state inside the bot's home
```

- [ ] **Step 3: Add to `home/files.nix`**

```nix
".claude-bot/CLAUDE.md".source = ../files/claude-bot/CLAUDE.md;
".claude-bot/.mcp.json".source = ../files/claude-bot/.mcp.json;
".claude-bot/memory/echo-personality.md".source       = ../files/claude-bot/memory/echo-personality.md;
".claude-bot/memory/pranav-profile.md".source         = ../files/claude-bot/memory/pranav-profile.md;
".claude-bot/memory/pranav-claude-insights.md".source = ../files/claude-bot/memory/pranav-claude-insights.md;
".claude-bot/memory/alacritty-keybindings.md".source  = ../files/claude-bot/memory/alacritty-keybindings.md;
".claude-bot/memory/nix-setup.md".source              = ../files/claude-bot/memory/nix-setup.md;
".claude-bot/memory/scripbox-repositories.md".source  = ../files/claude-bot/memory/scripbox-repositories.md;
".claude-bot/memory/vpn-setup.md".source              = ../files/claude-bot/memory/vpn-setup.md;
".claude-bot/memory/secret-rotation-helpers.md".source = ../files/claude-bot/memory/secret-rotation-helpers.md;
```

- [ ] **Step 4: Remove originals + switch**

```bash
SRC=~/.claude-bot
rm -f "$SRC/CLAUDE.md" "$SRC/.mcp.json"
for f in echo-personality pranav-profile pranav-claude-insights alacritty-keybindings \
         nix-setup scripbox-repositories vpn-setup secret-rotation-helpers; do
  rm -f "$SRC/memory/$f.md"
done
cd ~/dotfiles && make switch
test -L ~/.claude-bot/CLAUDE.md                       && echo "CLAUDE.md         symlinked"
test -L ~/.claude-bot/memory/echo-personality.md      && echo "echo-personality  symlinked"
```

- [ ] **Step 5: Commit**

```bash
git add files/claude-bot/ home/files.nix
git commit -m "phase-1: track ~/.claude-bot/{CLAUDE.md,.mcp.json,memory/<curated>}"
```

---

## Task 11: Migrate `~/.zshrc` (HIGHEST RISK — last)

**Files:**
- Create: `~/dotfiles/files/zshrc`
- Modify: `~/dotfiles/home/files.nix`

This is load-bearing: every new shell sources `~/.zshrc`. If the symlink ends up broken, new shells start in a degraded state. Mitigation: **keep a backup copy in `$HOME`** until verified.

- [ ] **Step 1: Backup + copy + verify byte equality**

```bash
cp -p ~/.zshrc ~/.zshrc.preHM   # backup in HOME for fast rollback
cp -p ~/.zshrc ~/dotfiles/files/zshrc
shasum ~/.zshrc ~/dotfiles/files/zshrc
```
Expected: identical SHAs.

- [ ] **Step 2: Add to `home/files.nix`**

```nix
".zshrc".source = ../files/zshrc;
```

- [ ] **Step 3: Remove original + switch**

```bash
rm ~/.zshrc
cd ~/dotfiles && make switch
test -L ~/.zshrc && echo "zshrc symlinked"
shasum ~/.zshrc ~/dotfiles/files/zshrc   # symlink resolves to same bytes
```

- [ ] **Step 4: Open a FRESH shell and verify**

In a new terminal window/tab (so we test the actual user-facing behaviour):
```bash
# Inside the new shell:
echo $PATH | tr ':' '\n' | grep -E '\.local/bin|nix-profile' | head
which secret && secret get _doesnt_exist_$$ ; echo "secret get returned $?"
which shelltest && echo "shelltest alias present"
which metabase_token && echo "metabase_token function present"
```
Expected: PATH contains `~/.local/bin` and `~/.nix-profile/bin`; `secret get` returns nonzero with the usage error (proves the function loaded); `shelltest` is found; `metabase_token` is a function.

- [ ] **Step 5: If verification passes, remove the backup**

```bash
rm ~/.zshrc.preHM
```

- [ ] **Step 6: Commit**

```bash
git add files/zshrc home/files.nix
git commit -m "phase-1: track ~/.zshrc (the load-bearing one)"
```

**Rollback (if step 4 reveals a regression):**
```bash
# in the affected shell:
mv ~/.zshrc.preHM ~/.zshrc       # symlink gets replaced by the backup
# then `git revert HEAD` once we identify the cause; re-run home-manager switch
```

---

## Task 12: Add `bat` to `home.packages`

**Files:**
- Modify: `~/dotfiles/home/packages.nix`

`bat` was installed ad-hoc via `nix profile install` earlier; declare it here so Phase 1 includes it reproducibly.

- [ ] **Step 1: Update `home/packages.nix`**

```nix
{ pkgs, ... }: {
  home.packages = [
    pkgs.bat
  ];
}
```

- [ ] **Step 2: Remove the ad-hoc profile install + switch**

```bash
nix profile remove bat 2>/dev/null || nix profile remove nixpkgs#bat 2>/dev/null || true
cd ~/dotfiles && make switch
which bat && bat --version
```
Expected: `bat` now comes from the HM-managed profile (`~/.nix-profile/bin/bat` still resolves; HM uses an HM-specific profile under the hood).

- [ ] **Step 3: Commit**

```bash
git add home/packages.nix
git commit -m "phase-1: declare bat in home.packages (replaces ad-hoc nix profile install)"
```

---

## Task 13: Pre-commit secrets scanner

**Files:**
- Create: `~/dotfiles/.githooks/pre-commit`
- Modify: `~/dotfiles/Makefile` (install hook on `make install`)

Belt-and-braces — Keychain holds the actual secrets, but the hook refuses any accidental commit of a JWT, Slack token, or long base64-looking blob.

- [ ] **Step 1: Write `.githooks/pre-commit`**

```bash
#!/usr/bin/env bash
# Refuse to commit obvious secrets. Belt-and-braces on top of the Keychain
# discipline. Patterns: JWTs, Slack tokens, GitHub PATs, AWS keys, long
# base64-url runs in staged content.
set -u
fail=0
note() { printf '  pre-commit: %s\n' "$1" >&2; }
patterns=(
  'eyJ[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}'   # JWT
  'xox[abprs]-[A-Za-z0-9-]{20,}'                                   # Slack
  'ghp_[A-Za-z0-9]{30,}'                                           # GitHub PAT
  'AKIA[0-9A-Z]{16}'                                               # AWS access key
  '-----BEGIN (RSA|OPENSSH|EC) PRIVATE KEY-----'                   # SSH/PGP
)
for p in "${patterns[@]}"; do
  hits=$(git diff --cached -U0 | grep -aE "^\+" | grep -aE "$p" || true)
  if [ -n "$hits" ]; then
    note "FAIL: pattern matched: $p"
    note "$(printf '%s' "$hits" | head -5)"
    fail=1
  fi
done
[ "$fail" -ne 0 ] && note "blocked. (use --no-verify only if you are SURE)" && exit 1
exit 0
```

- [ ] **Step 2: Update `Makefile`'s `install` target** to set core.hooksPath

Modify the `install:` block in `Makefile` to additionally run:
```make
install:
	@command -v nix >/dev/null || (echo "Install Nix first: sh <(curl -L https://nixos.org/nix/install) --daemon" && exit 1)
	git config core.hooksPath .githooks
	chmod +x .githooks/pre-commit
	nix run home-manager/release-24.11 -- switch --flake .#$(USER)
	$(MAKE) test
```

- [ ] **Step 3: Activate the hook locally + test it blocks a fake secret**

```bash
cd ~/dotfiles
git config core.hooksPath .githooks
chmod +x .githooks/pre-commit
# fake JWT in a sandbox file:
echo "TEST=eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJ4eHh4eHh4eHh4eHh4eHh4eHh4eCJ9.abcdefghij" > /tmp/__fake_secret
git add -N /tmp/__fake_secret 2>/dev/null || true
# Now try to stage and commit:
git add docs/   # innocuous
echo "TEST=eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJ4eHh4eHh4eHh4eHh4eHh4eHh4eCJ9.abcdefghij" >> README.md
git add README.md
git commit -m "test commit (should fail)" 2>&1 | tee /tmp/precommit_out
grep -q "FAIL: pattern matched" /tmp/precommit_out && echo "hook blocked as expected"
# unstage the bad change:
git restore --staged README.md
git checkout -- README.md
```

- [ ] **Step 4: Commit the hook itself**

```bash
git add .githooks/pre-commit Makefile
git commit -m "phase-1: add .githooks/pre-commit secrets scanner; wire via make install"
```

---

## Task 14: Final full smoke + push to GitHub

**Files:** none new.

- [ ] **Step 1: Re-run smoke and the home-manager activation**

```bash
cd ~/dotfiles
make switch    # idempotent; should report "no changes" or one trivial diff
make test      # full smoke
```
Expected: smoke prints `✅ smoke PASSED`.

- [ ] **Step 2: Confirm no surprise un-tracked changes in $HOME**

```bash
ls -la ~/.zshrc ~/.config/starship.toml ~/.config/alacritty/alacritty.toml ~/.claude/settings.json ~/.claude-bot/CLAUDE.md ~/.local/bin/har-extract | awk '{print $1, $NF}'
```
Expected: every listed file is a symlink (`l` in mode) pointing into `/nix/store/...`.

- [ ] **Step 3: Create the GitHub repo and push**

```bash
cd ~/dotfiles
gh repo create Pranavj17/dotfiles --public --source=. --remote=origin --description "macOS dev env, declared in Nix (Home Manager + nix-darwin)"
git push -u origin main
gh repo view --web   # opens the new repo
```

- [ ] **Step 4: Tag the milestone**

```bash
git tag -a phase-1 -m "Phase 1 complete: Home Manager with out-of-store symlinks. Backup goal achieved."
git push origin phase-1
```

---

## Done criteria for Phase 1

- [ ] `make switch` succeeds clean, `make test` is green.
- [ ] Every file in the spec's "Tracked" inventory exists as a `/nix/store` symlink in `$HOME`.
- [ ] `~/dotfiles` pushed to `Pranavj17/dotfiles` on GitHub, tagged `phase-1`.
- [ ] Pre-commit hook blocks fake secrets.
- [ ] On a fresh shell: prompt renders, `shelltest` passes (28/28), `bat`/`har-extract`/`claude-export-split` all work.

After Phase 1: the laptop-swap promise is **partially** delivered — you still need Nix + this repo on a new mac, but every user-level dotfile reproduces in one `make install`. Phase 2 (nix-darwin) brings the system layer.
