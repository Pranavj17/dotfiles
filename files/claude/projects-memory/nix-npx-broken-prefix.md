---
name: nix-npx-broken-prefix
description: "Nix nodejs in ~/.nix-profile breaks `npx -y <pkg>`, breaking npx-based MCP servers/plugins; fix via ~/.npmrc prefix"
metadata: 
  node_type: memory
  type: project
  originSessionId: bd2370b5-4b31-4d15-9166-7af3a883965c
---

The Nix-provided node in `~/.nix-profile/bin` breaks `npx -y <pkg>` (and `npm` global ops). `node`/`npx --version` work, but installing/running a package fails with `ENOENT lstat <prefix>/lib`. Cause: the full `nodejs-20.20.2` package's `bin/node` is itself a symlink to `nodejs-slim-20.20.2`, so npm canonicalizes `process.execPath` to the slim build and computes its global prefix as `.../nodejs-slim-20.20.2/lib`, which doesn't exist in the slim output.

**Impact:** any npx-based MCP server / Claude Code plugin silently fails to start. Seen as `Failed to reconnect to plugin:graylog-log-search:graylog: -32000` when running `/plugin`. The `-32000` just means the MCP child process never came up.

**Fix (verified 2026-05-25):**
```
mkdir -p ~/.npm-global/lib/node_modules ~/.npm-global/bin
printf 'prefix=/Users/pranav.j/.npm-global\n' > ~/.npmrc
```
Then `npm config get prefix` → `/Users/pranav.j/.npm-global` and `npx -y mcp-server-graylog` boots fine. After applying, reload the plugin / restart Claude Code so the MCP server re-spawns. No prior `~/.npmrc` existed and no global packages lived under the broken prefix, so this is non-destructive.

Related: [[dev-env-nix-toolchain]].
