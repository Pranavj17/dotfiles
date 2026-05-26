---
name: secrets-keychain-preference
description: "Pranav's secret-management preference on macOS: store in login Keychain via `security` CLI, fetch on-demand; never ciphertext+key in a dotfile"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: cddb8318-22a8-4054-b2e5-ef8f94280319
---

For secrets on this macOS machine, use the **login Keychain** (OS-encrypted), fetched on demand — never write a secret (or an encrypted blob whose key sits beside it) into `.zshrc`/dotfiles/global env.

- **Store/rotate:** `security add-generic-password -a "you@scripbox.com" -s my-service -w 'pass' -U` (`-U` = update existing).
- **Fetch:** `security find-generic-password -s my-service -a "you@scripbox.com" -w` — wrap in a zsh helper func and call `$(my_secret)` at use sites so the value only lives in memory when invoked.
- **Rejected:** "encrypt a blob + drop it in `.zshrc`" — if the decrypt key is next to the ciphertext it's not protected. Let macOS own key management.

**Universal helper (in `~/.zshrc`, added 2026-05-26):** `secret set <name> [value]` (hidden prompt if value omitted, `-U` updates), `secret get <name>` (use in `$(secret get NAME)`), `secret rm <name>`. Account defaults to `$SECRET_ACCOUNT` (pranav.j@scripbox.com). Prefer this over hand-rolled per-secret functions.

**Rotation helpers (in `~/.zshrc`, added 2026-05-26):**
- `rotate_metabase` — changes the Metabase password via `PUT /api/user/{id}/password` (uses `metabase_token`), verifies HTTP 200, then `secret set scripbox-metabase`. Fully scriptable.
- `rotate_graylog` — mints a new Graylog token via `POST $GRAYLOG_BASE_URL/api/users/{uid}/tokens/{name}` (needs VPN + Graylog password from Keychain `scripbox-graylog` or prompt), stores via `secret set GRAYLOG_API_TOKEN`, then points at old tokens to DELETE. Verify token path per Graylog version at `/api/api-browser`. Untested (was off-VPN at write time).
- **GRAYLOG_API_TOKEN migrated out of plaintext** (2026-05-26): `~/.zshrc` now does `export GRAYLOG_API_TOKEN="$(secret get GRAYLOG_API_TOKEN)"`. The old plaintext token was exposed in the dotfile + a Slack note + this transcript → should be rotated, not just hidden.
- **Can't rotate without UI:** Asana PATs (mint only in developer console; Service Accounts are Enterprise/super-admin) and Sentry user/org tokens (Settings → Auth Tokens). For these, mint in UI then `secret set <name>`.

**Why:** stated preference (Pranav's own Slack note, 2026-05-26, sent via the Claude Slack app). **How to apply:** whenever a task involves an API token / password on this machine, default to this Keychain pattern rather than env vars in dotfiles. Already used for `GRAYLOG_API_TOKEN` and the `scripbox-metabase` creds (see [[metabase-lead-id-lookup]]); it's also the intended source for the statusline 🚦 triage chip's `ASANA_ACCESS_TOKEN`/`SENTRY_AUTH` (see [[nested-claude-headless-sandbox]] for the statusline build).
