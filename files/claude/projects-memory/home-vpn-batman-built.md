---
name: home-vpn-batman-built
description: Home VPN + ad-blocker Pi 5 (Batman) — Phase 1 shipped 2026-05-28 on ~/Documents/home-automation
metadata: 
  node_type: memory
  type: project
  originSessionId: ea7c60d0-f489-4dec-9b76-ea1e0364db68
---

Home VPN Pi 5 `Batman` is **live and complete** as of 2026-05-28.

**Why:** Operator wanted family-grade VPN + DNS ad-blocking + exit-node, with the option to expand into IoT VLAN in Phase 2.

**How to apply:** When the operator references "the home Pi", "Batman", "home VPN", or asks about LAN access / ad-blocking / Tailscale at home — that's this project. Don't propose Phase 2 work (IoT VLAN, Home Assistant) without checking; Phase 2 is its own spec that hasn't started.

**Topology:**
- Pi 5 hostname `Batman` (Tailscale node `batman`, tailnet `tailc12c52.ts.net`, IP `100.70.223.15`)
- Boots from 500GB Crucial P3 NVMe via M.2 HAT+; SanDisk 64GB microSD kept as labeled recovery card
- Home WiFi `pranav@3` at LAN IP `192.168.1.139` (wlan0 MAC `88:a2:9e:98:68:7d`, eth0 MAC `88:a2:9e:98:68:7c`)
- ISP: ACT Fibernet via ARRIS router at `192.168.1.1`, public WAN `49.205.37.84` (not CGNAT, port-forwarding available though not needed)

**Stack:**
- Pi OS Lite Trixie (Debian 13), kernel `6.12.75+rpt-rpi-2712`
- User `pranav`, password locked (`lock_passwd: true`), SSH key only, NOPASSWD sudo
- Tailscale 1.98+ — advertises `192.168.1.0/24` subnet route + exit node; auto-update on; key expiry disabled
- AdGuard Home bound to `100.70.223.15:53` (DNS) and `:80` (admin) — Cloudflare + Quad9 DoH upstreams
- MagicDNS forces all tailnet clients through AdGuard regardless of WiFi/cellular
- ufw deny-in / allow-out, SSH 22 + tailscale0; unattended-upgrades nightly with 03:00 IST auto-reboot

**Operational:**
- Weekly age-encrypted backups via rsync from Pi to MacBook `~/Documents/home-automation/backups/home-vpn/`, 8-snapshot retention. Mac LAN IP currently `192.168.1.146`; if it changes update `/etc/home-vpn/backup.conf`.
- 5-min monitoring cron alerts to ntfy.sh topic stored in Keychain `home-vpn-ntfy-topic`.

**Keys (Mac Keychain, account = `pranav.j@scripbox.com` for the `secret` zsh helper, account = `pranav` for the home-vpn-* ones we made before the convention was clear):**
- `home-vpn-pi` — Pi user password (locked at Pi side, but kept as console-recovery fallback)
- `home-vpn-adguard` — AdGuard admin pw
- `home-vpn-age-identity` — age private key for decrypting backups
- `home-vpn-ntfy-topic` — monitor alert topic name (acts as shared secret)
- `TAILSCALE_API_KEY` — Tailscale REST API token (exported as `$TAILSCALE_API_KEY` via `~/dotfiles/files/zsh/functions.zsh`)

**Pi state files at `/etc/home-vpn/`:**
- `age-identity.key`, `age-recipient.pub` (root:root 0600)
- `backup.conf` (root:root 0640)
- `ntfy-topic` (root:root 0640)
- `tailscale-api-key` (root:pranav 0640; loaded into `$TAILSCALE_API_KEY` via Pi `~/.bashrc`)

**Repo:** [github.com/Pranavj17/home-automation](https://github.com/Pranavj17/home-automation) (private). Spec at `docs/superpowers/specs/2026-05-27-home-vpn-design.md`, plan at `docs/superpowers/plans/2026-05-27-home-vpn.md`, scripts in `pi/scripts/` and `mac/scripts/`.

**Operator-pending TODO (not blocking but worth tracking):**
1. Rotate the original Tailscale API key (`tskey-api-...CNTRL-Rto...`) — it appeared in the implementation conversation.
2. First family member invite via `https://login.tailscale.com/admin/users`.
3. Optionally move Pi to wired Ethernet for full Gigabit throughput (currently WiFi-only, ~100-400 Mbps cap on exit-node traffic).
4. Pull microSD from Pi when convenient; relabel.

**Links:** [[scripbox-vpn-endpoint]] (work tailnet pattern this mirrors), [[dotfiles-repo]] (where `TAILSCALE_API_KEY` is wired), [[secrets-keychain-preference]] (Keychain-first secret pattern).
