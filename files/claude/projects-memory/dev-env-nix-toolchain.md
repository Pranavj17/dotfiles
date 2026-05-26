---
name: dev-env-nix-toolchain
description: "Memory project dev env runs via Nix+direnv; mix must use the Nix toolchain (OTP 27), not the also-installed Homebrew Elixir (OTP 28)"
metadata: 
  node_type: memory
  type: project
  originSessionId: b7ea1ff6-e246-4cb9-96e2-d1b89ab57b3d
---

On this machine the Memory project's dev environment is Nix (`shell.nix`) + direnv (`.envrc` does `if has nix; then use nix; fi`). The Nix toolchain is Elixir 1.18.4 / Erlang OTP 27.

**Gotcha:** Homebrew Elixir is ALSO installed (1.19.5 / OTP 28, `/opt/homebrew/bin`). The interactive login shell — which is what the `memory` alias and Claude use — correctly resolves `mix` to the Nix Elixir (because `.envrc`'s `use nix` prepends it). But non-interactive shells and `direnv exec` (started from a non-direnv PATH) resolve to the Homebrew `mix` instead. Running mix across the two toolchains, or leaving a stale global `~/.mix/archives/hex-*` built under the wrong OTP, causes `Error loading module 'Elixir.Hex': corrupt atom table`.

**Why:** Hex/rebar and `_build` are compiled per OTP major version; OTP 27 can't load BEAM/Hex built under OTP 28.

**Shell userland is GNU, not BSD:** Nix puts GNU coreutils first on PATH, so on this macOS box `stat`, `date`, `sed` etc. behave like Linux, NOT BSD. e.g. mtime is `stat -c %Y` (GNU), not `stat -f %m` (BSD) — a `stat -f %m` call does NOT error under GNU stat, it silently prints filesystem info, so write portable shell as `stat -c %Y "$f" 2>/dev/null || stat -f %m "$f"` (GNU first). Bit me writing the statusline renderer.

**How to apply:** Always run mix under the Nix toolchain — e.g. inside a real `nix-shell`/direnv-loaded interactive shell. After an Elixir/OTP change: remove any incompatible `~/.mix/archives/hex-*`, run `mix local.hex --force && mix local.rebar --force` under Nix, `rm -rf _build`, then `mix deps.get && mix compile`. Backing services run via `docker compose up -d` (containers `memory_postgres`, `memory_chroma`); `mix setup` (alias added in mix.exs) does deps.get + ecto.create + ecto.migrate on `memory_dev`. The SessionStart hook (`.claude/hooks/session-start.sh`) calls `mix run -e "Memory.boot_info()"`, so it depends on all of the above. See [[memory-alias-launch]].
