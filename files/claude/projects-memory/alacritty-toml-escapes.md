---
name: alacritty-toml-escapes
description: Editing ~/.config/alacritty/alacritty.toml — uXXXX escapes get mangled to raw control bytes by Edit/Write/heredoc; write via Python chr(92). Cmd+Enter newline in Claude Code = Ctrl+J.
metadata: 
  node_type: memory
  type: reference
  originSessionId: b7ea1ff6-e246-4cb9-96e2-d1b89ab57b3d
---

Editing `~/.config/alacritty/alacritty.toml` key bindings that need control chars in `chars = "..."` (e.g. Ctrl-U = u0015, Ctrl+J = backslash-n, ESC = u001b).

**Gotcha:** the Edit/Write tools AND bash heredocs mangle backslash escapes in transit — a `backslash-u-001b` arrives in the file as a raw ESC byte (0x1b), and `backslash-r` is inconsistently interpreted. A raw control byte inside a TOML basic string is **invalid TOML**, so Alacritty fails with `invalid basic string, expected non-double-quote visible characters` and refuses to load the config (red error banner).

**Fix:** write the file with Python, building the backslash from `chr(92)` so only plain ASCII passes through the tool/JSON layer, leaving the literal escape *text* in the file for TOML to parse:
```python
bs = chr(92)
nl     = bs + "n"               # file text: backslash-n -> TOML parses to LF (0x0a)
ctrl_u = bs + "u0015"           # file text -> Ctrl-U (0x15)
```
Always validate after writing: `tomllib.load(...)` and check parsed `chars` equals the intended byte (e.g. `'\n'` / `'\x15'`).

**Key bindings in this file:**
- Cmd+Enter -> Ctrl+J (LF, 0x0a) = Claude Code's **universal** newline (no `/terminal-setup` needed). This is the correct one for the Claude Code TUI. Do NOT use ESC+CR (that's Meta+Enter; Claude Code wants kitty-protocol Shift+Enter, not that). Caveat: at a bare zsh prompt Ctrl+J means *submit*, so this binding is TUI-only. Other Claude Code newline options: backslash-then-Enter (universal), or Shift+Enter after running `/terminal-setup` (writes a kitty-protocol binding; officially supports Alacritty).
- Shift+Enter -> Ctrl+J (LF, 0x0a), same as Cmd+Enter (added 2026-05-25). Without this binding Shift+Enter sends default CR (0x0d) = submit, so it won't make a newline. Chose an explicit `chars = "\n"` binding (byte-identical to Cmd+Enter) over `/terminal-setup`'s kitty-protocol approach for simplicity/consistency.
- Cmd+Delete -> Ctrl-U (0x15), zsh kill-whole-line.
- Cmd+T / Cmd+Opt+Left/Right -> macOS native tab actions (CreateNewTab / SelectPreviousTab / SelectNextTab).

Font: `MesloLGS Nerd Font` size 12 (standard). The Nerd Font is from Nix (`nerd-fonts.meslo-lg`) but macOS only sees fonts copied into `~/Library/Fonts` — see [[dev-env-nix-toolchain]]. Alacritty live-reloads on save.
