{ pkgs, ... }: {
  imports = [
    ./defaults.nix
    ./packages.nix
    ./homebrew.nix
    ./launchd.nix
  ];

  # nix-darwin requires this to declare ownership of the system configuration.
  # Bumped only when nix-darwin docs say to.
  system.stateVersion = 6;

  # Apple Silicon
  nixpkgs.hostPlatform = "aarch64-darwin";

  # The primary user for user-scoped options (homebrew, launchd.user.*).
  system.primaryUser = "pranav.j";

  # Enable flakes + nix-command for darwin-rebuild itself.
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Required so /run/current-system points at our config after activation.
  programs.zsh.enable = true;
}
