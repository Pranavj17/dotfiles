{ pkgs, ... }: {
  # All packages declaratively managed via Home Manager. To add or remove a
  # tool, edit this list and `make switch`. The set lives at ~/.nix-profile/.
  home.packages = with pkgs; [
    # Editor / pager / shell aids
    bat
    fzf
    ripgrep

    # git's own /nix/store/...-git-*/etc/gitconfig already sets
    # credential.helper = osxkeychain. Do not also generate a Home Manager
    # gitconfig; that duplicated the helper and, on stateVersion 24.11,
    # injected gpg.program.
    git

    # JS / Node
    bun
    nodejs_20
    yarn

    # Python (general use). The `dwim` corrector's MLX runtime lives in a pip
    # venv (~/.venvs/dwim) instead — Nix's mlx is CPU-only (no Metal backend).
    python311

    # AWS / infra
    awscli2
    chamber
    sops
    terraform
    terragrunt

    # Kubernetes
    kubectx
    kubelogin-oidc

    # SSH / remote
    sshpass

    # Was Homebrew. autojump's shell hook is sourced from shell.nix.
    # colima keeps using ~/.colima; this is only the CLI.
    autojump
    colima
    docker
    docker-compose
    ffmpeg

    # Fonts
    nerd-fonts.meslo-lg
  ];
}
