{ pkgs, ... }: {
  imports = [ ./files.nix ./packages.nix ];

  home.username      = "pranav.j";
  home.homeDirectory = "/Users/pranav.j";
  home.stateVersion  = "24.11";  # do not change after first switch

  programs.home-manager.enable = true;
}
