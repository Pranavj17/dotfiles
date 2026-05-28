---
name: feedback-downloads-via-curl
description: "Operator prefers `curl` background downloads over directing them to click links in Chrome/Safari"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: ea7c60d0-f489-4dec-9b76-ea1e0364db68
---

When the operator needs to download a file (ISOs, VM images, large archives, dataset blobs, etc.), use `curl -L -o <path> "$URL" &` directly in the Bash tool. Do NOT default to "open this URL in your browser" and have them click.

**Why:** Operator explicitly asked for this 2026-05-28 during the Kali ISO setup — curl is faster, shows progress, can be backgrounded so they keep working, and avoids the friction of switching to a browser to manage downloads. Also avoids architecture-confusion problems (their Chrome session pulled the wrong amd64 image because of unclear UI; explicit curl URLs eliminate that ambiguity).

**How to apply:**
- Default for any file ≥10 MB: kick off via curl, ideally backgrounded with `nohup ... &`.
- Pipe progress to a temp log file (`/tmp/<name>-dl.log`) so I can re-check status across messages.
- Save the PID (`echo $! > /tmp/<name>-dl.pid`) for later status checks.
- Verify URL works first with `curl -sI` — Kali, kernel.org, etc. sometimes change paths between releases.
- For 7-zipped / tar archives, also kick off the unpack inline after the curl finishes (don't wait for the operator to ask).
- Exception: if the user explicitly wants to click (sometimes for license-acceptance pages or interactive flows), respect that.

Specific patterns from this session worth keeping:
- Search for current filename by listing the parent directory first: `curl -s https://cdimage.kali.org/kali-XYZ/ | grep -oE 'href="[^"]*"'` — Kali changes architecture suffixes between releases.
- Backgrounded curl status check: `ls -lh <file>` for current size; `ps -p $(cat /tmp/<name>-dl.pid)` for liveness.

Related: [[secrets-keychain-preference]] (same operator's "don't make me click through dotfiles to find a thing" philosophy).
