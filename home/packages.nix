{ pkgs, ... }: {
  # All packages declaratively managed via Home Manager. To add or remove a
  # tool, edit this list and `make switch`. The set lives at ~/.nix-profile/.
  home.packages = with pkgs; [
    # Editor / pager / shell aids
    bat
    fzf
    ripgrep

    # JS / Node
    bun
    nodejs_20
    yarn

    # Python
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

    # Fonts
    meslo-lg
  ];
}
