---
type: workflow
tags: [nix, devenv, direnv, macos]
created: 2026-05-25
updated: 2026-05-25
---

# Nix Development Environment Setup

## Deterministic System
- Uses Determinate Nix (declarative package management on macOS)
- All-Nix dev environment with direnv for automatic shell loading
- Ensures reproducible builds and dependencies

## Shell & Terminal
- Terminal: Alacritty with zsh + Starship prompt
- Fast startup, GPU-accelerated rendering
- Custom keybindings for productivity (Alt+U for URL navigation, etc.)

## Integration
- Works seamlessly with Scripbox development (Elixir/Phoenix services)
- Database tools and Ruby on Rails environments provisioned via Nix
- IDE integration via direnv auto-loads when entering project directories

## Related
- [[alacritty-keybindings]] — terminal key mappings
- [[scripbox-repositories]] — uses Nix for dependency management
