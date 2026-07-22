---
name: aqua-signal-map-ungated
description: TODO — aqua.pranavjagadish.com (Tailnet Signal Map) is live + PUBLIC + UNGATED; needs edge auth
metadata: 
  node_type: memory
  type: project
  originSessionId: 6a874e4d-98ad-45fa-8736-d33a04faa644
---

Tailnet Signal Map shipped 2026-05-30 and is **live, public, and ungated** at `https://aqua.pranavjagadish.com` (radial DNS-traffic viz on Batman; `aquarium.service`, codename kept; repo `~/Documents/home-automation`, merged to main via PR #3).

**Security state:** network layer is already tight — service binds `127.0.0.1:8126` only, ufw default-deny with no inbound port for it, reachable only via outbound Cloudflare Tunnel, HTTPS enforced, cloudflared current. The **one open gap is authentication at the edge**: anyone with the URL loads it, and the websocket streams device names + queried domains + activity timing = a live map of the home network.

**TODO (deferred by Pranav 2026-05-30, decide later):** close the gap with one of —
- **Tailnet-only (strongest, CLI-doable):** drop the `aqua` ingress in `/etc/cloudflared/config.yml` (backup `config.yml.bak.aqua` exists) + `cloudflared tunnel route dns` removal, bind to tailnet IP `100.70.223.15`, restart. Only tailnet devices reach it.
- **Cloudflare Access (keep public + login wall):** CF Zero Trust → Access → Applications → Self-hosted → `aqua.pranavjagadish.com`, policy = allow only Pranav's email. Free ≤50 users. Dashboard-only.

**Why:** outward-facing personal infra leaking household DNS cadence (occupancy signal); should not stay open indefinitely.
**How to apply:** when revisited, ask which posture; tailnet-only can be done immediately over LAN SSH `pranav@192.168.1.139`. Also consider data-minimization (ws exposes raw domains) and tightening ufw SSH `22/tcp ALLOW IN Anywhere` → tailscale0+LAN.

Related: [[home-vpn-batman-built]], [[scripbox-vpn-endpoint]]
