---
type: workflow
tags: [secrets, keychain, rotation, zsh, security]
created: 2026-05-25
updated: 2026-05-25
---

# Secret rotation helpers (macOS, no web UI)

Universal Keychain wrapper in `~/.zshrc`: `secret set|get|rm <name>` (account = `$SECRET_ACCOUNT` = pranav.j@scripbox.com). Secrets live in the login Keychain, never plaintext in dotfiles. See [[pranav-profile]].

**Rotation (added 2026-05-26):**
- `rotate_metabase` — changes Metabase password via `PUT /api/user/{id}/password` (uses `metabase_token`), verifies HTTP 200, then `secret set scripbox-metabase`. Fully scriptable.
- `rotate_graylog` — mints token via `POST $GRAYLOG_BASE_URL/api/users/{uid}/tokens/{name}` → `secret set GRAYLOG_API_TOKEN` → revoke old. Needs VPN + Graylog password (Keychain `scripbox-graylog` or prompt). Verify token path per version at `/api/api-browser`. Untested (off-VPN at write).
- **Asana PAT & Sentry tokens: UI-only to mint** (no API). After minting in UI: `secret set ASANA_ACCESS_TOKEN` / `secret set SENTRY_AUTH`.

**Migrated `GRAYLOG_API_TOKEN` out of plaintext** in `.zshrc` (now `$(secret get GRAYLOG_API_TOKEN)`). It had been exposed in the dotfile + a Slack note + a Claude transcript → **rotate it**, don't just hide it.

Posted a how-to to Slack DM `D041DG9B5DF`.
