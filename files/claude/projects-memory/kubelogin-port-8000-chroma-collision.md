---
name: kubelogin-port-8000-chroma-collision
description: "k9s/kubectl OIDC login \"redirects to localhost:8000\" and hangs because the memory project's ChromaDB owns port 8000; fix = kubelogin --listen-address 18000"
metadata: 
  node_type: memory
  type: project
  originSessionId: bd2370b5-4b31-4d15-9166-7af3a883965c
---

Running `k9s`/`kubectl` against the Scripbox **production** cluster (`ap-south-1-production.scripbox.net`) triggers Google OIDC via int128 `kubelogin`, which spins up a local OAuth callback server on `http://localhost:8000`. But this machine's **`memory_chroma`** container (chromadb/chroma, a docker-compose backing service of the memory project, forwarded by Colima) already publishes `0.0.0.0:8000`. The browser's OAuth redirect to `localhost:8000/?code=...` lands on ChromaDB instead of kubelogin, so login never completes — symptom: "k9s opens / keeps redirecting to localhost:8000". Cluster/VPN/DNS are fine; production API answers HTTP 401 (reachable, just needs a token). VPN is Tailscale (MagicDNS `100.100.100.100`); note `api.staging.scripbox.org` is NXDOMAIN on this tailnet, so the staging context can't connect here at all.

**Fix applied 2026-05-25:** added `--listen-address=127.0.0.1:18000` to the `production-kubernetes-user` exec args in `~/.kube/config` (port 18000 was free). Backup at `~/.kube/config.bak.20260525-170644`. Open question: requires `http://localhost:18000` to be a registered redirect URI in the kubelogin Google OAuth client — if Google returns `redirect_uri_mismatch`, fall back to temporarily stopping `memory_chroma` to free 8000, log in, then restart it. The first login is interactive (Google SSO) and must be done by the user.

Related: [[k8s-apps-context]] (see docs/k8s_apps_context.md in the memory repo).
