# Spec — `update-claude.sh`: backup-then-update Claude Code

**Date:** 2026-05-26 · **Status:** approved (verbal "yes"), pending user review of this file

## Context

`claude` (Claude Code CLI) is installed via `bun install -g @anthropic-ai/claude-code` and lives at `~/.bun/bin/claude` → `~/.bun/install/global/node_modules/@anthropic-ai/claude-code-darwin-arm64/claude`. Updates are typically applied via `bun update -g @anthropic-ai/claude-code` or by Claude's own auto-updater (governed by `autoUpdate` in `~/.claude/settings.json`).

A Claude update can change formats for: session JSONL transcripts, auto-saved memory `.md` files, plugin cache metadata, settings.json schema. Of those, the mutable state at risk on disk (not already protected by the dotfiles git repo) is:

- `~/.claude/projects/` — transcripts + memory dirs (incl. `auto-*.md`)
- `~/.claude/sessions/` — saved session state
- `~/.claude-bot/.remember/` — Echo's persistent memory
- `~/.claude-bot/crons/`, `~/.claude-bot/processes/` — Echo runtime state
- `~/.claude-bot/memory/auto-*.md` — Echo auto memos

Everything else under `~/.claude/{settings.json, keybindings.json, statusline-command.sh, statusline/*, projects/-Users-pranav-j-Documents-memory/memory/<12 curated>.md}` and `~/.claude-bot/{CLAUDE.md, .mcp.json, memory/<8 curated>.md}` is HM-symlinked into `/nix/store/` from `~/dotfiles/files/`, so those are recoverable from the dotfiles git repo without local backup.

Plugin cache (`~/.claude/plugins/`, ~163 MB) is intentionally excluded — Claude re-fetches plugin metadata on next launch if needed.

## Goals

- One manually-run command (`~/Documents/update-claude.sh`) that backs up at-risk state then updates Claude.
- Backup is **always** complete before any update is attempted; a half-finished tar must abort before `bun update`.
- Interactive: show current vs. latest version, prompt `y/N` before updating. Default no.
- Idempotent: safe to re-run any time. Each run is a fresh dated snapshot.
- Disable Claude's auto-update so the script is the single update path.

## Non-goals

- Restore script. Restore is a one-liner (`tar -xzf <backup>.tar.gz -C /`) documented in the script's `--help`. Adding a separate restore script doubles design surface for a rare action.
- Cron / unattended automation. The script is interactive by design. A wrapper for unattended use (`yes | …`) is the user's call later.
- Plugin-cache backup. Plugins re-fetch from the registry; not worth the 163 MB.
- Update path beyond `bun update -g`. No npm fallback, no version pinning, no rollback. The backup IS the rollback.

## Architecture

### Files this spec creates / modifies

| Path | Action | Source-of-truth |
|---|---|---|
| `~/Documents/update-claude.sh` | create | local (not tracked in dotfiles repo — script is personal) |
| `~/dotfiles/files/claude/settings.json` | modify (add `"autoUpdate": false`) | dotfiles git |
| `~/Documents/claude-backups/` | created at first run | local (never tracked) |
| `~/Documents/claude-backups/YYYY-MM-DD-HHMMSS.tar.gz` | written per run | local (never tracked) |

Decision: the script lives in `~/Documents/`, NOT `~/dotfiles/scripts/`, because the user explicitly said "in documents" and because the backup tarballs live next to it — co-located logic and data.

### Script flow

```
1. Parse args (--help | --dry-run | --backup-only | <no args>)
2. Pre-flight checks:
   - bun on PATH? (abort if missing — needed for both version check and update)
   - claude on PATH? (warn if missing — backup still runs)
   - ~/Documents/claude-backups/ exists? (mkdir -p)
3. Resolve versions:
   - cur = `claude --version` (or "unknown" if not installed)
   - latest = `bun pm view @anthropic-ai/claude-code version` OR
              `curl -s https://registry.npmjs.org/@anthropic-ai/claude-code/latest | jq -r .version`
              (whichever resolves; fall back to "unknown" on net failure)
4. BACKUP (always, even on --dry-run print only):
   stamp=$(date +%Y-%m-%d-%H%M%S)
   tmp=~/Documents/claude-backups/${stamp}.tar.gz.partial
   final=~/Documents/claude-backups/${stamp}.tar.gz
   tar -czf "$tmp" \
     -C "$HOME" \
     .claude/projects \
     .claude/sessions \
     .claude-bot/.remember \
     .claude-bot/crons \
     .claude-bot/processes \
     $(ls .claude-bot/memory/auto-*.md 2>/dev/null) \
     $(ls .claude-bot/{daemon.pid,session-id} 2>/dev/null)
   mv "$tmp" "$final"
   Print: bytes + entry count.
5. EXIT EARLY (--backup-only): print "backup saved to $final"; exit 0
6. UPDATE CHECK:
   - If cur == latest: print "already at $cur (latest)"; exit 0 (backup is the entire payoff)
   - If cur == "unknown" OR latest == "unknown": print warning, still prompt
7. PROMPT (skip on --dry-run):
   read "Update Claude $cur → $latest? [y/N] " ans
   case y|Y) proceed; *) print "skipped (backup at $final)"; exit 0;;
8. UPDATE:
   bun update -g @anthropic-ai/claude-code
9. POST-CHECK:
   newcur = `claude --version`
   if newcur != latest: warn (update may have failed)
   print success + backup path + new version
```

### Settings change

In `~/dotfiles/files/claude/settings.json`, add at top level:
```json
"autoUpdate": false
```

After the change, run `cd ~/dotfiles && home-manager switch --flake .#pranav.j` to deploy via HM symlink.

### Error handling

- `set -euo pipefail` top of script.
- Pre-flight failures abort with non-zero before any backup or update.
- Tar failure: `.partial` file is left for inspection; script aborts; NO update attempted.
- Net failure for version check: degrade to "(latest unknown)"; user can still proceed.
- Update failure: backup remains; script exits non-zero with message pointing at backup path.
- All errors go to stderr; success messages to stdout.

### Backup format

- `tar -czf` — gzipped tar. Standard, portable, transparent.
- Filename `YYYY-MM-DD-HHMMSS.tar.gz` sorts chronologically.
- Working dir for tar is `$HOME` so paths inside the archive are relative (`.claude/projects/...`). Restore: `tar -xzf <file> -C "$HOME"`.

## Testing approach

- `update-claude.sh --dry-run` on a fresh install: prints planned tar command + bun update command, creates no files. Verify exit 0.
- `update-claude.sh --backup-only` on current state: creates tarball, exits before prompt. Verify: tarball exists, has expected entry count (≥ 1 file from each included subtree), is valid (`tar -tzf` returns 0).
- `update-claude.sh` (interactive, already-latest case): prints "already at latest", creates tarball, exits 0. Verify no `bun update` ran.
- `update-claude.sh` (interactive, update-available case): manual test when a real update lands. Verify: backup before update, prompt fires, update runs, new version reported.
- Edge: `~/.claude-bot/` partially exists (e.g. fresh install without daemon.pid yet) → tar should skip missing inputs gracefully without aborting.

## Risks

- **User runs `bun update -g` directly instead of the script.** Mitigated by disabling Claude's autoUpdate (one less unwatched path), but `bun update` is still trivially typeable. We accept this — the protection is the user's habit, not the script's enforcement.
- **Restore is a manual operation the user may fumble** (wrong `-C` dir, restoring over current state, etc.). Mitigated by printing exact restore command in `--help` and on every backup-saved message.
- **Backup tarball corruption** (disk full, killed mid-write). Mitigated by `.partial` rename: only finalized files have the canonical name. Script checks that before proceeding to update.
- **No version pinning.** If a Claude release ships a regression, the script happily upgrades. The backup IS the recovery: `bun install -g @anthropic-ai/claude-code@<prev>` to downgrade, then `tar -xzf` to restore state. Acceptable for personal use.

## Open questions

None at design time. If the implementation surfaces issues (e.g. `bun pm view` doesn't exist on the installed bun version, requiring a fallback to direct npm registry curl), capture them in the implementation plan and revise here.

## References

- Echo memory: `nix-setup` (the HM/nix-darwin context this lives alongside)
- Claude Code auto-memory: `dotfiles-repo`, `brew-bundle-cleanup-uninstall-pitfall`
- Spec author lessons baked into this design: backup-before-update, fail-closed (no update on bad backup), explicit > implicit, YAGNI on restore-script.
