{
  description = "Pranav's dotfiles — Home Manager (Phase 1 bootstrap)";

  inputs = {
    nixpkgs.url      = "github:NixOS/nixpkgs/nixpkgs-unstable";
    home-manager = {
      url            = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, home-manager, ... }:
    let
      system = "aarch64-darwin";
      pkgs   = import nixpkgs { inherit system; };
    in {
      homeConfigurations."pranav.j" = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        modules = [ ./home/default.nix ];
      };
    };
}
