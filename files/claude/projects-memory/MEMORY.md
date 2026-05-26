# Memory Index

- [Dev env: Nix toolchain](dev-env-nix-toolchain.md) — run mix under Nix (OTP 27), not Homebrew (OTP 28); avoids "corrupt atom table"
- [milky-way repo](milky-way-repo.md) — Scripbox Rails 5.2 app; clone via HTTPS (SSH blocked), Ruby 2.7.7 via nix shell.nix + direnv
- [Nix npx broken prefix](nix-npx-broken-prefix.md) — Nix node breaks `npx -y`; breaks plugin MCP servers (-32000); fix via ~/.npmrc prefix
- [apps repo clean build](apps-repo-clean-build.md) — ~/Documents/apps: clear nested deps/*/_build (OTP-28 pc plugin corrupt atom table), mix compile before format, push needs interactive keychain
- [kubelogin port 8000 vs ChromaDB](kubelogin-port-8000-chroma-collision.md) — k9s prod OIDC hangs on localhost:8000 (memory_chroma owns it); fixed via kubelogin --listen-address 18000
- [Alacritty TOML escapes](alacritty-toml-escapes.md) — \uXXXX escapes get mangled to raw control bytes by Edit/Write/heredoc; write via Python chr(92). Cmd+Enter & Shift+Enter newline = Ctrl-J (\n); font MesloLGS Nerd Font
- [claude-bot needs bun](claude-bot-plugin-bun.md) — claude-bot plugin MCP server is `bun run server.ts`; install bun via Nix + bun install in plugin dir or tools never register; daemon=launchd com.claude-bot.daemon, bot home ~/.claude-bot (personality "Echo")
- [Scripbox VPN endpoint](scripbox-vpn-endpoint.md) — WORKING VPN = Tailscale/Headscale (prod subnet router) → code.scripbox.io + cluster reachable (node sb-111/100.65.0.52); old Tunnelblick/OpenVPN .ovpn is dead/superseded
- [Metabase lead_id lookup](metabase-lead-id-lookup.md) — email→lead_id via metabase.scripbox.net auth_production(db13).accounts_user; `metabase_lead_id` zsh helper, creds in Keychain (scripbox-metabase)
- [Nested claude -p sandbox](nested-claude-headless-sandbox.md) — scripts calling `claude -p` must use `--strict-mcp-config` from a neutral dir, else "Prompt is too long" (261k MCP tools) + fires project hooks
- [Secrets via Keychain](secrets-keychain-preference.md) — prefers macOS login Keychain (`security` add/find-generic-password), fetched on-demand in .zshrc; never ciphertext+key in a dotfile
- [Advisory FP title-merge bug](advisory-fp-title-merge-bug.md) — FP summary merged possibility/new by goal title; duplicate titles → wrong per-goal numbers; possibility reorders by priority + id tracks goal; FIXED via correlation-id match in financial_plan.ex
- [Scripbox k8s deploy](scripbox-k8s-deploy.md) — k8s-apps repo + nocodb kustomize precedent; kubectl auth=Google OIDC/kubelogin (NOT AWS SSO); .net=internal/.com=public+cloudflare; chamber/SSM secrets; ECR via GitLab CI
- [Helixa project](helixa-project.md) — RM Customer360/briefing FastAPI (~/Documents/helixa), Zoho-iframe-embedded, ClickHouse; Mac Mini→k8s (helixa.scripbox.com) migration; chat via claude -p
- [Advisory Peach Argus arity bug](advisory-peach-portfolio-argus-arity.md) — pre-existing: peach/portfolio.ex calls Advisory.Argus.user_graph/2 but only /1 exists → UndefinedFunctionError + failing test; fallout from FP-era Argus /2→/1 refactor
- [NVIDIA Flux Schnell quirks](nvidia-flux-schnell-quirks.md) — ai.api.nvidia.com Flux Schnell needs cfg_scale=0, steps≤4; JPEG response; content filter blocks trademarked character names → describe emblem instead
- [minibot Mac mini](minibot-mac-mini.md) — minibot@10.10.30.4 (SB-312.local), M4 Pro arm64, keyless SSH via id_ed25519; Ollama text LLMs only, NO image-gen software, NO NVIDIA hardware
- [dotfiles repo](dotfiles-repo.md) — ~/dotfiles HM-standalone flake → out-of-store symlinks for zshrc/starship/alacritty/.claude/.claude-bot/.local/bin; `make switch`; remote: Pranavj17/dotfiles tagged phase-1
