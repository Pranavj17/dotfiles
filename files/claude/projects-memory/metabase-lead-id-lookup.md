---
name: metabase-lead-id-lookup
description: "How to get a customer's lead_id by email via Scripbox Metabase + the zsh helper"
metadata: 
  node_type: memory
  type: reference
  originSessionId: 6600995e-97bb-4bae-b037-6818208cb359
---

Scripbox Metabase: `https://metabase.scripbox.net`. Username/password auth works via `POST /api/session` (not SSO-blocked) for `pranav.j@scripbox.com`.

**email → lead_id mapping** lives in `auth_production` (Metabase database id **13**), table `accounts_user`, columns `email` + `lead_id`. (`clientmaster_production` db 29 `accounts_user` has `lead_id` but no email column — email is on the auth side, linked by `auth_id`. `auth_production.sales_lead` also has email+lead_id for pre-conversion leads.)

Canonical lead_id format is 32-char hex without dashes (e.g. `395b5907191af52d755901ea04934aef`); some rows are UUID-with-dashes from newer signups. One email can have **multiple** lead_ids (employees accumulate test accounts) — prefer `email_verified = true`, oldest `inserted_at`.

zsh helpers in `~/.zshrc`: `metabase_lead_id <email>`, plus `metabase_token` / `metabase_password`. Credentials are in the **macOS login Keychain** (service `scripbox-metabase`, account `pranav.j@scripbox.com`), fetched on demand via `security find-generic-password -w` — never plaintext in dotfiles. Rotate with `security add-generic-password ... -U`. This is the correct pattern; the older `GRAYLOG_API_TOKEN` is still plaintext in `.zshrc` and should be migrated the same way. Related: [[scripbox-repositories]].
