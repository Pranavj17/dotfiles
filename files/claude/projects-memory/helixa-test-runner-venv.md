---
name: helixa-test-runner-venv
description: "Run helixa pytest/ruff via ~/Documents/helixa/.venv/bin, not the Nix base python (no pytest)"
metadata: 
  node_type: memory
  type: reference
  originSessionId: 86ccab66-fee9-4f76-a0e6-c6fa0feaa9c5
---

In ~/Documents/helixa, run tests and lint through the project venv, NOT the Nix base python (which has no pytest module — `python -m pytest` → "No module named pytest").

- Tests: `~/Documents/helixa/.venv/bin/python -m pytest tests/mcp -q`
- Lint: `~/Documents/helixa/.venv/bin/ruff check <paths>`

Project is hatchling + pytest>=8 + pytest-asyncio (pyproject `[tool.pytest.ini_options]`, testpaths=["tests"]). No `uv`/`direnv` test wrapper present; `.venv/bin/` is the reliable entrypoint. GitLab remote = code.scripbox.io/scripbox/helixa; push MRs via `git push -o merge_request.create -o merge_request.target=main`. Related: [[dev-env-nix-toolchain]] [[helixa-project]]
