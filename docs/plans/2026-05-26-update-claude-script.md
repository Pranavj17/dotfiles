# `update-claude.sh` Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship `~/Documents/update-claude.sh` — a bash script that backs up mutable Claude state before updating Claude Code via `bun update -g @anthropic-ai/claude-code`, plus disable Claude's auto-updater so this script is the single update path.

**Architecture:** Single bash script (`set -euo pipefail`) with three modes: `--help`, `--dry-run`, `--backup-only`, and the default (interactive update). Backup is a tar.gz to `~/Documents/claude-backups/YYYY-MM-DD-HHMMSS.tar.gz` containing only mutable non-HM state. Version detection via `claude --version` + npm registry. Settings change in `~/dotfiles/files/claude/settings.json` deployed via `home-manager switch`.

**Tech Stack:** bash, tar, curl + jq (or `bun pm view`), bun.

---

## File Structure

| Path | Action | Tracked? |
|---|---|---|
| `~/Documents/update-claude.sh` | create | NO (per spec — personal local script) |
| `~/Documents/claude-backups/` | created at first run | NO |
| `~/Documents/claude-backups/*.tar.gz` | one per run | NO |
| `~/dotfiles/files/claude/settings.json` | modify (add `"autoUpdate": false`) | YES (dotfiles repo) |

Each step that touches `~/dotfiles/files/claude/settings.json` ends in a git commit. Steps that only touch `~/Documents/update-claude.sh` end in a `chmod +x` + a quick verification command — no git commit (untracked by design).

---

## Task 1: Scaffold the script — shebang, strict mode, arg parsing, `--help`

**Files:**
- Create: `~/Documents/update-claude.sh`

- [ ] **Step 1: Write the initial script with arg parsing**

```bash
cat > ~/Documents/update-claude.sh <<'EOF'
#!/usr/bin/env bash
# update-claude.sh — backup mutable Claude state, then update `claude` CLI.
#
#   ./update-claude.sh             # interactive: backup → version check → y/N prompt → bun update
#   ./update-claude.sh --dry-run   # print what would happen; no files written, no update
#   ./update-claude.sh --backup-only   # backup only; skip the update prompt and update
#   ./update-claude.sh --help      # this message
#
# Backups land in ~/Documents/claude-backups/YYYY-MM-DD-HHMMSS.tar.gz
# Restore: `tar -xzf <backup>.tar.gz -C "$HOME"` (from a fresh terminal)
#
# See spec: ~/dotfiles/docs/specs/2026-05-26-update-claude-script-design.md

set -euo pipefail

# ── argument parsing ────────────────────────────────────────────────────
MODE=interactive
for arg in "$@"; do
  case "$arg" in
    --help|-h)        MODE=help ;;
    --dry-run)        MODE=dry_run ;;
    --backup-only)    MODE=backup_only ;;
    *) echo "update-claude.sh: unknown argument: $arg" >&2
       echo "Try: update-claude.sh --help" >&2
       exit 2 ;;
  esac
done

if [ "$MODE" = help ]; then
  sed -n '2,12p' "$0" | sed 's/^# \?//'
  exit 0
fi

# Implementation continues in later tasks (Task 2 onward).
echo "TODO: scaffold only — implementation lands in later tasks. MODE=$MODE"
EOF
chmod +x ~/Documents/update-claude.sh
```

- [ ] **Step 2: Verify `--help` works**

Run: `~/Documents/update-claude.sh --help`
Expected output (verbatim, no leading `# `):
```
update-claude.sh — backup mutable Claude state, then update `claude` CLI.

  ./update-claude.sh             # interactive: backup → version check → y/N prompt → bun update
  ./update-claude.sh --dry-run   # print what would happen; no files written, no update
  ./update-claude.sh --backup-only   # backup only; skip the update prompt and update
  ./update-claude.sh --help      # this message

Backups land in ~/Documents/claude-backups/YYYY-MM-DD-HHMMSS.tar.gz
Restore: `tar -xzf <backup>.tar.gz -C "$HOME"` (from a fresh terminal)
```
Exit code 0.

- [ ] **Step 3: Verify unknown flag aborts**

Run: `~/Documents/update-claude.sh --bogus`
Expected stderr (verbatim):
```
update-claude.sh: unknown argument: --bogus
Try: update-claude.sh --help
```
Exit code: `2`.

- [ ] **Step 4: Verify the no-arg path runs the placeholder**

Run: `~/Documents/update-claude.sh`
Expected stdout:
```
TODO: scaffold only — implementation lands in later tasks. MODE=interactive
```
Exit 0.

- [ ] **Step 5: No commit — script is untracked by spec.**

Confirm: `ls -la ~/Documents/update-claude.sh` shows `-rwxr-xr-x` (executable bit set). No `git add` needed.

---

## Task 2: Pre-flight checks (bun required, claude warn, backup dir)

**Files:**
- Modify: `~/Documents/update-claude.sh` — add `preflight()` function, call before MODE dispatch

- [ ] **Step 1: Insert the `preflight()` function** just before the `MODE=help` branch (after the `for arg in "$@"; do … done` loop)

Replace the script's body between `# ── argument parsing ───` and `if [ "$MODE" = help ]; then` with this block (the arg parsing loop stays):

```bash
# ── pre-flight ──────────────────────────────────────────────────────────
preflight() {
  if ! command -v bun >/dev/null 2>&1; then
    echo "update-claude.sh: bun not on PATH — install it first (nix profile add nixpkgs#bun or via home.packages)" >&2
    exit 3
  fi

  if ! command -v claude >/dev/null 2>&1; then
    echo "update-claude.sh: WARNING — claude not on PATH; backup will still run, version check skipped." >&2
    CLAUDE_PRESENT=0
  else
    CLAUDE_PRESENT=1
  fi

  BACKUP_DIR="$HOME/Documents/claude-backups"
  mkdir -p "$BACKUP_DIR"
}

if [ "$MODE" != help ]; then
  preflight
fi
```

The remainder of the file (`if [ "$MODE" = help ]; then …`) stays as in Task 1.

- [ ] **Step 2: Verify `--help` still works without running preflight**

Run: `~/Documents/update-claude.sh --help`
Expected: same usage text as Task 1 Step 2. Exit 0.

- [ ] **Step 3: Verify preflight aborts if `bun` is missing**

```bash
PATH=/usr/bin:/bin ~/Documents/update-claude.sh --dry-run
```
Expected stderr (verbatim):
```
update-claude.sh: bun not on PATH — install it first (nix profile add nixpkgs#bun or via home.packages)
```
Exit code: `3`.

- [ ] **Step 4: Verify preflight succeeds + backup dir exists**

```bash
~/Documents/update-claude.sh --dry-run
ls -d ~/Documents/claude-backups/
```
Expected:
- Script prints the `TODO` placeholder line + `MODE=dry_run`.
- `ls -d` shows the directory exists (created by `mkdir -p` even if it already did).
- Exit 0.

- [ ] **Step 5: Simulate missing claude — warning fires, doesn't abort**

```bash
# Force claude off PATH by stripping ~/.bun/bin (the only dir holding it on this machine):
NEW_PATH=$(echo "$PATH" | tr ':' '\n' | grep -v '/.bun/bin' | paste -sd: -)
PATH="$NEW_PATH" ~/Documents/update-claude.sh --dry-run
```
Expected: WARNING line about claude not on PATH, then the `TODO` placeholder. Exit 0.

- [ ] **Step 6: No commit (script untracked).**

---

## Task 3: Version resolution — current + latest from registry

**Files:**
- Modify: `~/Documents/update-claude.sh` — add `resolve_versions()` function

- [ ] **Step 1: Add `resolve_versions()` after `preflight()`**

Append the following AFTER the closing `}` of `preflight()` and BEFORE the `if [ "$MODE" != help ]` block:

```bash
# ── version resolution ─────────────────────────────────────────────────
# Sets CUR (current claude version or "unknown") and LATEST (npm registry
# version of @anthropic-ai/claude-code, or "unknown" on failure).
resolve_versions() {
  if [ "${CLAUDE_PRESENT:-0}" = 1 ]; then
    # claude --version prints e.g. "2.1.150 (Claude Code)" — take the first whitespace token.
    CUR=$(claude --version 2>/dev/null | awk '{print $1; exit}')
    [ -z "$CUR" ] && CUR=unknown
  else
    CUR=unknown
  fi

  # Try `bun pm view` first (fast, no extra deps). Fall back to direct npm registry.
  LATEST=$(bun pm view @anthropic-ai/claude-code version 2>/dev/null | tr -d '\r' || true)
  if [ -z "$LATEST" ]; then
    LATEST=$(curl -fsS --max-time 5 https://registry.npmjs.org/@anthropic-ai/claude-code/latest 2>/dev/null \
              | sed -nE 's/.*"version":"([^"]+)".*/\1/p' \
              | head -n1)
  fi
  [ -z "$LATEST" ] && LATEST=unknown
}
```

- [ ] **Step 2: Call `resolve_versions` from the main flow + print them**

Replace the placeholder block at the bottom of the script (the `echo "TODO:` line) with:

```bash
if [ "$MODE" != help ]; then
  resolve_versions
  echo "claude (current): $CUR"
  echo "claude (latest):  $LATEST"
  echo "(scaffold — backup + update flows land in later tasks. MODE=$MODE)"
fi
```

- [ ] **Step 3: Verify current + latest both resolve in normal case**

Run: `~/Documents/update-claude.sh --dry-run`
Expected stdout (versions will be real):
```
claude (current): 2.1.150
claude (latest):  <some semver>
(scaffold — backup + update flows land in later tasks. MODE=dry_run)
```
Exit 0.

- [ ] **Step 4: Verify "unknown" fallback when claude is off PATH**

```bash
NEW_PATH=$(echo "$PATH" | tr ':' '\n' | grep -v '/.bun/bin' | paste -sd: -)
PATH="$NEW_PATH" ~/Documents/update-claude.sh --dry-run
```
Expected: WARNING about missing claude, then `claude (current): unknown`. Exit 0.

- [ ] **Step 5: No commit.**

---

## Task 4: Backup function — tar.gz with `.partial` rename, explicit include list

**Files:**
- Modify: `~/Documents/update-claude.sh` — add `do_backup()` function + wire `--backup-only` mode

- [ ] **Step 1: Add `do_backup()` after `resolve_versions()`**

Insert this block after the closing `}` of `resolve_versions()`:

```bash
# ── backup ─────────────────────────────────────────────────────────────
# Writes BACKUP_FILE on success; aborts (leaving a .partial) on failure.
do_backup() {
  local stamp tmp final inputs
  stamp=$(date +%Y-%m-%d-%H%M%S)
  tmp="$BACKUP_DIR/${stamp}.tar.gz.partial"
  final="$BACKUP_DIR/${stamp}.tar.gz"

  # Build an include list of paths that EXIST under $HOME.
  # Paths are relative to $HOME so the archive restores via `tar -xzf <file> -C "$HOME"`.
  inputs=()
  for p in \
    .claude/projects \
    .claude/sessions \
    .claude-bot/.remember \
    .claude-bot/crons \
    .claude-bot/processes; do
    [ -e "$HOME/$p" ] && inputs+=("$p")
  done
  # Auto memory dumps (glob — may be empty).
  while IFS= read -r -d '' f; do
    inputs+=("${f#"$HOME/"}")
  done < <(find "$HOME/.claude-bot/memory" -maxdepth 1 -name 'auto-*.md' -print0 2>/dev/null)
  # Per-conversation auto memory inside the curated memory dir
  while IFS= read -r -d '' f; do
    inputs+=("${f#"$HOME/"}")
  done < <(find "$HOME/.claude/projects/-Users-pranav-j-Documents-memory/memory" -maxdepth 1 -name 'auto-*.md' -print0 2>/dev/null)
  # Optional daemon-state pointers (small).
  for p in .claude-bot/daemon.pid .claude-bot/session-id; do
    [ -f "$HOME/$p" ] && inputs+=("$p")
  done

  if [ "${#inputs[@]}" -eq 0 ]; then
    echo "update-claude.sh: nothing to back up (no source paths found under \$HOME)" >&2
    return 0
  fi

  if [ "$MODE" = dry_run ]; then
    echo "[dry-run] would tar -czf $final containing:"
    printf '  %s\n' "${inputs[@]}"
    return 0
  fi

  echo "Backing up ${#inputs[@]} input(s) to $final ..."
  if ! tar -C "$HOME" -czf "$tmp" "${inputs[@]}"; then
    echo "update-claude.sh: tar failed; partial archive left at $tmp" >&2
    exit 4
  fi
  mv "$tmp" "$final"

  local bytes count
  bytes=$(wc -c < "$final" | tr -d ' ')
  count=$(tar -tzf "$final" | wc -l | tr -d ' ')
  BACKUP_FILE="$final"
  echo "Backup saved: $final"
  echo "  size:    ${bytes} bytes"
  echo "  entries: ${count}"
  echo "  restore: tar -xzf \"$final\" -C \"\$HOME\""
}
```

- [ ] **Step 2: Wire `--backup-only` to call `do_backup` and exit**

Replace the bottom of the script (the version-printing block from Task 3 Step 2) with:

```bash
if [ "$MODE" != help ]; then
  resolve_versions
  echo "claude (current): $CUR"
  echo "claude (latest):  $LATEST"
  echo

  do_backup

  if [ "$MODE" = backup_only ]; then
    exit 0
  fi
  if [ "$MODE" = dry_run ]; then
    echo "[dry-run] would prompt for update + run: bun update -g @anthropic-ai/claude-code"
    exit 0
  fi

  # Interactive update path lands in Task 5.
  echo "(interactive update flow comes in Task 5; aborting for now.)"
fi
```

- [ ] **Step 3: Verify `--dry-run` lists inputs without writing**

```bash
ls ~/Documents/claude-backups/ 2>/dev/null | wc -l
~/Documents/update-claude.sh --dry-run
ls ~/Documents/claude-backups/ 2>/dev/null | wc -l
```
Expected:
- Pre count and post count are identical (no new tarball).
- Script prints `[dry-run] would tar -czf …` followed by an indented list including `.claude/projects`, `.claude/sessions`, `.claude-bot/.remember`, etc.
- Exit 0.

- [ ] **Step 4: Verify `--backup-only` writes a real tarball**

```bash
~/Documents/update-claude.sh --backup-only
ls -la ~/Documents/claude-backups/ | tail -3
```
Expected:
- Latest file is `YYYY-MM-DD-HHMMSS.tar.gz`, NOT `.partial`.
- Script printed `Backup saved`, `size`, `entries`, `restore` lines.
- Exit 0.

- [ ] **Step 5: Verify the tarball is valid and contains expected paths**

```bash
LATEST=$(ls -t ~/Documents/claude-backups/*.tar.gz | head -1)
tar -tzf "$LATEST" | head -10
tar -tzf "$LATEST" | grep -c '^\.claude/projects/'
```
Expected:
- `tar -tzf` exit 0 (archive valid).
- First 10 entries include `.claude/projects/` paths.
- Grep count >= 1 (projects dir was included).

- [ ] **Step 6: No commit.**

---

## Task 5: Interactive update flow — prompt + `bun update` + post-check

**Files:**
- Modify: `~/Documents/update-claude.sh` — replace the `(interactive update flow comes in Task 5; aborting for now.)` line with the real flow

- [ ] **Step 1: Replace the "comes in Task 5" placeholder with the real flow**

In the script, locate this block:

```bash
  # Interactive update path lands in Task 5.
  echo "(interactive update flow comes in Task 5; aborting for now.)"
```

Replace ONLY those two lines with:

```bash
  # ── update prompt + execution ─────────────────────────────────────────
  if [ "$CUR" != unknown ] && [ "$LATEST" != unknown ] && [ "$CUR" = "$LATEST" ]; then
    echo "Already at latest ($CUR). Backup saved; nothing to update."
    exit 0
  fi

  printf 'Update claude %s → %s? [y/N] ' "$CUR" "$LATEST"
  read -r ans
  case "${ans:-}" in
    y|Y|yes|YES)
      ;;
    *)
      echo "Skipped. Backup remains at $BACKUP_FILE"
      exit 0
      ;;
  esac

  echo "Running: bun update -g @anthropic-ai/claude-code"
  if ! bun update -g @anthropic-ai/claude-code; then
    echo "update-claude.sh: bun update failed. Backup remains at $BACKUP_FILE" >&2
    exit 5
  fi

  # Post-check.
  if command -v claude >/dev/null 2>&1; then
    NEWCUR=$(claude --version 2>/dev/null | awk '{print $1; exit}')
    echo
    echo "Done."
    echo "  before: $CUR"
    echo "  after:  ${NEWCUR:-unknown}"
    echo "  backup: $BACKUP_FILE"
    if [ -n "${NEWCUR:-}" ] && [ "$LATEST" != unknown ] && [ "$NEWCUR" != "$LATEST" ]; then
      echo "  WARNING: post-update version ($NEWCUR) doesn't match expected latest ($LATEST)." >&2
    fi
  else
    echo "WARNING: claude vanished from PATH after update?? Backup at $BACKUP_FILE" >&2
  fi
```

- [ ] **Step 2: Verify "already at latest" short-circuits**

If `claude --version` returns the same string as the npm latest, the script must NOT prompt. To trigger this deterministically without actually running an update:

```bash
~/Documents/update-claude.sh </dev/null
```
Expected (when already at latest): final line `Already at latest (X.Y.Z). Backup saved; nothing to update.` Exit 0. A new tarball IS created (backup runs first).

If versions differ (real update available), instead expect the y/N prompt to fire — which on `</dev/null` reads EOF and gets the default-no branch, printing `Skipped.`. Either outcome (already-latest OR skipped) is acceptable for this step; both prove the prompt logic.

- [ ] **Step 3: Verify "n" answer skips cleanly**

```bash
echo n | ~/Documents/update-claude.sh
```
Expected:
- Backup line printed.
- Version lines printed.
- (If not already-latest:) `Skipped. Backup remains at <path>`.
- Exit 0.

- [ ] **Step 4: Verify the "y" path with a real available update — MANUAL**

This step is for the engineer to run AT THE TIME a real Claude update is available (newer npm version exists). Skipped if `CUR == LATEST`. Procedure:

```bash
~/Documents/update-claude.sh
# at the prompt, type: y <Enter>
```
Expected:
- Backup printed before prompt.
- `bun update -g @anthropic-ai/claude-code` runs, prints bun's "installed" line.
- `Done. before/after/backup` block printed.
- Exit 0.

- [ ] **Step 5: No commit (script untracked).**

---

## Task 6: Disable Claude auto-update via `settings.json` (dotfiles repo)

**Files:**
- Modify: `~/dotfiles/files/claude/settings.json` (add `"autoUpdate": false` at top level)

- [ ] **Step 1: Inspect current settings.json**

```bash
cat ~/dotfiles/files/claude/settings.json | head -20
```
Note the top-level keys present. The new `"autoUpdate": false` should be inserted at the same indentation as other top-level keys.

- [ ] **Step 2: Add `"autoUpdate": false` using `jq` (preserves JSON shape)**

```bash
cd ~/dotfiles
jq '. + {"autoUpdate": false}' files/claude/settings.json > files/claude/settings.json.tmp
mv files/claude/settings.json.tmp files/claude/settings.json
```

- [ ] **Step 3: Verify the change**

```bash
jq .autoUpdate ~/dotfiles/files/claude/settings.json
```
Expected: `false`. (jq prints the JSON value with no quotes around booleans.)

- [ ] **Step 4: Deploy via Home Manager**

```bash
cd ~/dotfiles && home-manager switch --flake .#pranav.j
```
Expected: activation succeeds, ends without errors. `~/.claude/settings.json` now points to a new `/nix/store` path whose contents include the new key.

- [ ] **Step 5: Verify live state**

```bash
jq .autoUpdate ~/.claude/settings.json
```
Expected: `false`.

- [ ] **Step 6: Commit + push**

```bash
cd ~/dotfiles
git add files/claude/settings.json
git commit -m "claude: disable autoUpdate so update-claude.sh is the only update path"
git push origin main
```

---

## Task 7: Final end-to-end manual smoke

**Files:** none modified.

- [ ] **Step 1: Re-run `--help` (no preflight needed, exits before)**

Run: `~/Documents/update-claude.sh --help`
Expected: usage text printed, exit 0.

- [ ] **Step 2: Re-run `--dry-run` end to end**

Run: `~/Documents/update-claude.sh --dry-run`
Expected:
- Version lines printed.
- `[dry-run] would tar -czf …` with indented input list.
- `[dry-run] would prompt for update + run: bun update -g @anthropic-ai/claude-code`.
- Exit 0.
- `ls ~/Documents/claude-backups/` count unchanged compared to before this step.

- [ ] **Step 3: Re-run `--backup-only` (creates a real tarball)**

Run: `~/Documents/update-claude.sh --backup-only`
Expected:
- New `YYYY-MM-DD-HHMMSS.tar.gz` in `~/Documents/claude-backups/`.
- Script prints `Backup saved`, `size`, `entries`, `restore` lines.
- Exit 0.

- [ ] **Step 4: Re-run default interactive with EOF (skipped path)**

Run: `~/Documents/update-claude.sh </dev/null`
Expected: either `Already at latest …` OR `Skipped. Backup remains at …`. Either way, exit 0 and a new backup tarball present.

- [ ] **Step 5: Verify autoUpdate is off in live settings**

```bash
jq .autoUpdate ~/.claude/settings.json
```
Expected: `false`.

- [ ] **Step 6: Print final inventory**

```bash
ls -la ~/Documents/update-claude.sh
ls -la ~/Documents/claude-backups/
git -C ~/dotfiles log --oneline -3
```
Expected:
- Script is executable, ~120 lines.
- Backups dir has ≥ 2 `.tar.gz` files from the smoke steps.
- Top dotfiles commit is the Task 6 settings change.

---

## Done criteria

- `~/Documents/update-claude.sh` is executable and supports `--help`, `--dry-run`, `--backup-only`, and the default interactive flow.
- `~/Documents/claude-backups/` is populated by `--backup-only` and default runs.
- A new run prints current + latest versions, prompts y/N when an update is available, and runs `bun update -g @anthropic-ai/claude-code` only on `y`.
- `~/dotfiles/files/claude/settings.json` has `"autoUpdate": false`, deployed via HM, committed + pushed to `Pranavj17/dotfiles`.
- A bad backup (tar failure) leaves a `.partial` and never triggers an update.

After this plan: update Claude only via `~/Documents/update-claude.sh`. Restore from any tarball with `tar -xzf <file> -C "$HOME"`.
