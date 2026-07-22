---
name: statusline-token-stale-deploy
description: "statusline wrong token count was a stale nix-deployed artifact, not a source bug; make switch fixes it"
metadata: 
  node_type: memory
  type: reference
  originSessionId: 0ed36b0c-70a6-4652-97e0-cd02ff87120b
---

Claude Code statusline showing a wrong/rounded token count (e.g. "80.0k" or "160.0k" not matching Claude's own "N tokens") was NOT a source-code bug — the dotfiles `main` source already reads `.context_window.total_input_tokens` directly (exact context = input + cache_read + cache_creation, matches /context). The wrong number came from a **stale deployed nix-store artifact** (`~/.claude/statusline-command.sh` symlinks into `/nix/store/...`) built from an older commit that still derived `used_percentage/100 * context_window_size`. Since `used_percentage` is a coarse INTEGER, on the 1M model each 1% = 10,000 tokens → quantised to nearest 10k.

**Fix = `cd ~/dotfiles && make switch`** (redeploys current source). Don't edit the token logic — `main` is already correct and the simple `f_ctok`-direct form is preferred over guard/pct-fallback variants.

Debug tip: capture the live statusline JSON by temporarily repointing `.claude/settings.json` `statusLine.command` to a tee wrapper (`~/.claude/settings.json` is a nix symlink, so edits hit the store copy, not the dotfiles source — restore from backup after). The "N tokens" shown above the prompt is a FROZEN per-message stamp (baked into the transcript); the statusline is live — a small gap between them is timing, not miscalculation. Related: [[dotfiles-repo]]

**Deploy home-only changes without sudo:** `make switch` runs `sudo nix run nix-darwin` (system, needs password) THEN home-manager. The statusline/zsh are home-manager files, so `cd ~/dotfiles && nix run home-manager/release-24.11 -- switch --flake .#pranav.j` deploys them alone, no sudo. Nix builds from the WORKING TREE of tracked files (uncommitted+staged included; "Git tree is dirty" warning is expected) — so stage the file before switching.
