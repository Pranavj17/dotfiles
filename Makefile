.PHONY: install switch test update help
DARWIN_HOST ?= SB-111

help:
	@echo "make install   - first-time bootstrap on a new machine"
	@echo "make switch    - apply current flake to system + user env (+ run tests)"
	@echo "make test      - run smoke tests (without switching)"
	@echo "make update    - bump flake inputs and switch"

install:
	@command -v nix >/dev/null || (echo "Install Nix first: sh <(curl -L https://nixos.org/nix/install) --daemon" && exit 1)
	git config core.hooksPath .githooks
	chmod +x .githooks/pre-commit
	$(MAKE) switch

# `switch` applies nix-darwin and its Home Manager user environment, then smoke.
# scripts/switch.sh prints a short transcript instead of the raw activation log.
switch:
	DARWIN_HOST='$(DARWIN_HOST)' bash scripts/switch.sh

test:
	bash tests/smoke.sh

update:
	nix flake update
	$(MAKE) switch
