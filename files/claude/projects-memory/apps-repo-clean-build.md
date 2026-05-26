---
name: apps-repo-clean-build
description: "Clean-rebuild gotchas for ~/Documents/apps (Scripbox umbrella) — nested deps/_build corrupt atom table, cas/core compile order, osxkeychain push"
metadata: 
  node_type: memory
  type: reference
  originSessionId: d3d099c8-364f-4bdb-a5ef-8500cfd8bc39
---

Clean-rebuild gotchas for the Scripbox `apps` umbrella at `~/Documents/apps` (remote `code.scripbox.io/scripbox/apps`, Elixir 1.18 / OTP 27 via shell.nix). Relates to [[dev-env-nix-toolchain]].

**1. `rm -rf _build` is not enough after an OTP switch — also clear nested `deps/*/_build`.**
rebar3-based native deps (`snappyer`, `crc32cer`) cache a compiled `pc` (port_compiler) plugin at `deps/<dep>/_build/default/plugins/pc/ebin/pc.beam`. If that beam was built under Homebrew OTP 28, loading it under Nix OTP 27 fails with `beam_load.c: Error loading module pc: corrupt atom table` (OTP≥28 atom-table format). The top-level `rm -rf _build` does NOT touch these. Fix:
`find deps -maxdepth 2 -name _build -type d -exec rm -rf {} +` then `mix deps.compile snappyer crc32cer --force` (refetches `pc`, rebuilds the `.so` under OTP 27).

**2. From-scratch `mix format` can race on cas→core compile order.**
`mix format` runs loadpaths and compiles deps; on a fresh `_build` it can fail with `module Core.DefaultHTTPClient is not loaded` while compiling `apps/cas` (it `use`s the `Core.DefaultHTTPClient` macro from `apps/core`). Run a plain `mix compile` first (dependency-ordered) — then `mix format` succeeds. `mix format` legitimately fixed 4 pre-existing unformatted files (cas error/http_client/casparser generator, db/outbox).

**3. Push needs an interactive session.** Remote is HTTPS with the `osxkeychain` credential helper. In a non-interactive/harness shell `git fetch`/`push` hang on the keychain GUI approval (TCP+DNS fine, server returns 401 in <0.5s). Run pull/push from your own Terminal.
