# dotfiles

macOS dev environment for [@Pranavj17](https://github.com/Pranavj17), declared
in Nix (Home Manager + nix-darwin via flakes).

**Status:** spec landed, implementation in phases (see
[`docs/specs/2026-05-26-hm-darwin-bootstrap.md`](docs/specs/2026-05-26-hm-darwin-bootstrap.md)).

## Goals

- A fresh mac reaches the working environment in three commands.
- Every file currently floating in `$HOME` is tracked here.
- Secrets stay in macOS Keychain; the repo is safe to make public.

## Bootstrap on a fresh mac (the promise)

```sh
xcode-select --install
sh <(curl -L https://nixos.org/nix/install) --daemon
git clone git@github.com:Pranavj17/dotfiles ~/dotfiles && cd ~/dotfiles
nix run nix-darwin -- switch --flake .#$(hostname)
```
