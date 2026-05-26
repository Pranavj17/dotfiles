---
name: scripbox-vpn-endpoint
description: "Scripbox VPN — WORKING method is Tailscale/Headscale (prod subnet router) for code.scripbox.io + cluster; old Tunnelblick/OpenVPN .ovpn is dead/superseded"
metadata: 
  node_type: memory
  type: reference
  originSessionId: cfaf5a9a-8f48-4e4d-8ad7-94f3ce6a86ea
---

Scripbox internal services (GitLab `code.scripbox.io`, k8s prod API `api.ap-south-1-production.scripbox.net`) are reached via **Tailscale (Headscale control plane)** — NOT the old OpenVPN appliance.

**Working method (confirmed 2026-05-26):** Tailscale up **and** the `tailscale-production` subnet router connected (`100.65.0.1`, relay `headscale-production`) → `code.scripbox.io` reachable (HTTP 302); git push/pull + cluster access work. Pranav's node: `sb-111` / `100.65.0.52`. CLI: `/Applications/Tailscale.app/Contents/MacOS/Tailscale status` (not on PATH). **Failure tell:** `code.scripbox.io` times out on :443 while general internet (github.com) is fine → Tailscale/prod-router is down; reconnect it.

**Superseded (historical, do not rely on):** old DevOps SSL VPN (Tunnelblick/OpenVPN; alias `r-vpn`→`~/.vpn_connect`; config `sslvpn-devops.team-client-config`). The `.ovpn` hardcodes a dead `remote 14.143.244.194 8443`; `production-vpn.scripbox.io`→`15.207.5.223` times out from ACT home. Use Tailscale instead.

**Internal 10.10.x.x hosts** (Mac-Mini `10.10.30.4`/minibot, Cigar 10.10.14.10) — historically only via the old prod VPN. Re-verify whether the current Tailscale prod subnet router advertises `10.10.x.x` (earlier it did not).

Do NOT store VPN passwords in files/memory. Related: [[kubelogin-port-8000-chroma-collision]], [[scripbox-k8s-deploy]], [[helixa-project]].
