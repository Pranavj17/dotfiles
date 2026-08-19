{ pkgs, ... }: {
  imports = [ ./files.nix ./packages.nix ./starship.nix ./shell.nix ];

  home.username      = "pranav";
  home.homeDirectory = "/Users/pranav";
  home.stateVersion  = "24.11";  # do not change after first switch

  programs.home-manager.enable = true;
}
