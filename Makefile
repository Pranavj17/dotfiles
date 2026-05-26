.PHONY: install switch test update help
USER := pranav.j
# HOST := $(shell hostname -s)   # added in Phase 2 when darwinConfigurations are keyed by hostname

help:
	@echo "make install   - first-time bootstrap on a new machine"
	@echo "make switch    - apply current flake to user env (+ run tests)"
	@echo "make test      - run smoke tests (without switching)"
	@echo "make update    - bump flake inputs and switch"

install:
	@command -v nix >/dev/null || (echo "Install Nix first: sh <(curl -L https://nixos.org/nix/install) --daemon" && exit 1)
	nix run home-manager/release-24.11 -- switch --flake .#$(USER)
	$(MAKE) test

switch:
	nix run home-manager/release-24.11 -- switch --flake .#$(USER)
	$(MAKE) test

test:
	bash tests/smoke.sh

update:
	nix flake update
	$(MAKE) switch
