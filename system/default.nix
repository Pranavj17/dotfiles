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
  nixpkgs.config = {
    allowUnfree = true;
    permittedInsecurePackages = [
      "nodejs-20.20.2"
      "nodejs-slim-20.20.2"
    ];
  };

  # The primary user for user-scoped options (homebrew, launchd.user.*).
  system.primaryUser = "pranav";

  users.users.pranav = {
    name = "pranav";
    home = "/Users/pranav";
  };

  # Determinate Nix manages the Nix installation; disable nix-darwin's
  # native Nix management to avoid the "Determinate detected, aborting
  # activation" error.  Flakes + nix-command are already enabled by
  # Determinate's daemon config.
  nix.enable = false;

  # Required so /run/current-system points at our config after activation.
  programs.zsh.enable = true;
}
