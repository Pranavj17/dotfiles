.PHONY: install switch test update help
USER := pranav.j
HOST := $(shell hostname -s)

help:
	@echo "make install   - first-time bootstrap on a new machine"
	@echo "make switch    - apply current flake to system + user env (+ run tests)"
	@echo "make test      - run smoke tests (without switching)"
	@echo "make update    - bump flake inputs and switch"

install:
	@command -v nix >/dev/null || (echo "Install Nix first: sh <(curl -L https://nixos.org/nix/install) --daemon" && exit 1)
	git config core.hooksPath .githooks
	chmod +x .githooks/pre-commit
	sudo nix run nix-darwin -- switch --flake .#$(HOST)
	$(MAKE) test

switch:
	sudo nix run nix-darwin -- switch --flake .#$(HOST)
	$(MAKE) test

test:
	bash tests/smoke.sh

update:
	nix flake update
	$(MAKE) switch
