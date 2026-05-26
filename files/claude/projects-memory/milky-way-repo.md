---
name: milky-way-repo
description: "Scripbox milky-way Rails 5.2 app — clone via HTTPS (SSH/22 blocked), Ruby 2.7.7 via nix shell.nix + direnv, cloned at ~/Documents/milky-way"
metadata: 
  node_type: memory
  type: project
  originSessionId: b7ea1ff6-e246-4cb9-96e2-d1b89ab57b3d
---

Scripbox apps are on the internal GitLab at `code.scripbox.io` (group `scripbox`). Two cloned locally under `~/Documents`:

- **milky-way** — `https://code.scripbox.io/scripbox/milky-way` (hyphen, not `milky_way`/`milkyway`). Rails 5.2.8, Ruby 2.7.7, Bundler 2.1.4, **mysql2** DB. At `~/Documents/milky-way`.
- **myscripbox-api** — `https://code.scripbox.io/scripbox/myscripbox-api`. **Note the `my` prefix** — it is NOT `scripbox-api`/`scripbox_api` (those don't exist); searching for it failed until the exact name was given. Rails, Ruby 3.0.5, Bundler 2.2.33, **pg** (Postgres) DB. At `~/Documents/myscripbox-api`.

Default branch for both: `master`. Other confirmed repos under `scripbox/`: `clientmaster`, `telex`.

**Disambiguation — TWO different "milky way" codebases (don't conflate):**
1. **This one** — the standalone Rails 5.2 CRM at `~/Documents/milky-way` (MySQL, 293 tables). The big legacy monolith.
2. The Elixir umbrella sub-app `milky_way` inside `~/Documents/apps/apps/milky_way` — a **thin HTTP client/wrapper** (Finch) that authenticates users and fetches user details/action-items from the Milky Way service; owns no DB, runs no jobs. Its context doc is `context.milkyway` (see [[apps-repo-clean-build]]). The umbrella overview's "background jobs via Exq/Redis" label for milky_way is wrong — that was a stale description carried over from the Rails app.

**Local all-Nix run setup (done):** gems go to a writable location (Nix store is read-only) — set `bundle config --local path vendor/bundle` (or `BUNDLE_PATH`). DB servers run straight from the Nix packages in each `shell.nix` (no Docker):
- **myscripbox-api**: Nix Postgres 14.7 on **port 5433** (5432 is the memory project's Docker Postgres). `.envrc` exports `PGHOST=localhost PGPORT=5433`. `bundle exec rake db:create db:migrate` worked cleanly. App boots.
- **milky-way**: Nix MySQL 8.0.32 on :3306, user `root`/`mysql` with `mysql_native_password` (mysql2 0.5.2 needs it). Gotchas hit & solved: (1) `mysqld` start crashed with `undo_001 already exists` — after `mysqld --initialize-insecure`, delete the orphaned `undo_001`/`undo_002` files, then start. (2) `db/schema.rb` load failed `Row size too large (>65535)` on wide utf8mb4 report tables (e.g. `bse_client_master_report`) — load via bare ActiveRecord and down-convert ONLY failing tables `utf8mb4`→`utf8`. (3) App wouldn't boot (`Frequency.daily` undefined) until the CSV lookup tables (`db/csvs/*.csv`, listed in `db/seeds.rb` SEED_TABLE_NAMES) were seeded — replicate `sync_table!` (first_or_create per CSV row) with bare AR, no app boot. Schema = 293 tables. App boots (Rails 5.2.8). Heavier `rake db:seed` (banks/holidays/country SQL/doorkeeper) left for later.

**Cloning:** Port 22 (SSH) to `code.scripbox.io` is firewalled/timeout; **clone over HTTPS** — git uses the osxkeychain credential helper, so cached GitLab creds work without prompting. Plain `curl` to the raw-file API does NOT use those creds (redirects to sign-in), so use `git` (clone / ls-remote) instead. A blobless partial clone (`git clone --filter=blob:none`) is much faster on a slow connection while keeping full history.

**Ruby toolchain:** needs Ruby 2.7.7 (`.ruby-version`) + Bundler 2.1.4 (`Gemfile.lock` BUNDLED WITH). The repo ships a tracked `shell.nix` (pins old nixpkgs commits) giving exactly ruby_2_7 = 2.7.7, bundler 2.1.4, mysql80 + connector-c (mysql2 gem), imagemagick6 (rmagick gem), nodejs 18, libffi, pkg-config, cmake. A local `.envrc` (`use nix`, git-excluded) auto-loads it via direnv. Ruby 2.7 is EOL and current nixpkgs has dropped it; the pinned commit predates the OpenSSL-1.1-insecure marking, so no NIXPKGS_ALLOW_INSECURE needed. See [[dev-env-nix-toolchain]].
