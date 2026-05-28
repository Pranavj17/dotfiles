---
name: kali-docker-lab
description: "Kali Rolling Docker container on Mac via Colima — `kali` zsh function from dotfiles; ARM64 native, NET_RAW cap, persistent /work volume"
metadata: 
  node_type: memory
  type: project
  originSessionId: ea7c60d0-f489-4dec-9b76-ea1e0364db68
---

Operator's Kali learning lab lives in a **Docker container** on the Mac, not a UTM VM.

**Why:** UTM path needed graphical install + manual clicks. Operator wanted unattended setup. Docker via Colima gave native-ARM64 Kali in <5 min with full CLI tool access.

**How to apply:** If operator asks "open Kali" or starts security/pentest work, the entry point is the `kali` zsh function (defined in `~/dotfiles/files/zsh/functions.zsh`). Bash shell drops into the running container; pass any command to run it inline (`kali nmap scanme.nmap.org`).

**Stack:**
- Container `kali` on Colima's Docker daemon (`/Users/pranav.j/.colima/default/docker.sock`)
- Image `kali:tools` (locally committed, 4.6 GB) — Kali Rolling + `kali-tools-top10` metapackage
- Caps `NET_RAW`, `NET_ADMIN` (so Nmap SYN scans, raw-socket tooling work)
- Volume `~/Documents/kali-work` → `/work` inside; survives container/image rebuilds
- Restart policy `unless-stopped`; container survives Mac reboots once Colima is up

**Tools confirmed working:**
- `nmap` (SYN scans verified against scanme.nmap.org)
- `msfconsole` (Metasploit Framework 6.4.x)
- `sqlmap`
- `hydra`
- `john` (the Ripper)
- `tshark` / wireshark CLI
- `responder`

**Tools NOT in top10 — install on demand:**
- `hashcat`, `gobuster`, `ffuf`, `zaproxy`, `bloodhound`, `burpsuite` (GUI — won't work in container anyway; install on Mac via brew for GUI tools)

**To rebuild image after major updates:**
```
docker rm -f kali
docker run -it --name kali --hostname kali \
  --cap-add NET_RAW --cap-add NET_ADMIN \
  -v "$HOME/Documents/kali-work:/work" -w /work \
  kalilinux/kali-rolling bash
# inside: apt update && apt install -y --no-install-recommends kali-tools-top10
# (or add specific extras)
# detach (Ctrl-P Ctrl-Q) or run inline
docker commit kali kali:tools
```

**Limitations (vs UTM-VM Kali):**
- No GUI — no Burp Suite UI, no Wireshark UI, no graphical browser-based labs
- No monitor-mode WiFi (no kernel access to wireless interfaces — same as iOS)
- Some Kali tools assume systemd / dbus and won't fully work; container is rootless-ish
- Workflows that need a browser stay on the Mac/host

**Path forward if GUI eventually wanted:** UTM ARM64 install from the Kali netinst ISO already at `~/Downloads/kali-linux-2026.1-installer-netinst-arm64.iso`. Container is the fast lane; UTM is for when GUI tools are needed.

**Related:**
- [[home-vpn-batman-built]] — Tailscale gives mobile/remote access to the Mac (and thus this container) from anywhere
- [[feedback-downloads-via-curl]] — curl-driven download workflow used to get the Kali ISO
- [[dotfiles-repo]] — `kali` function lives here
