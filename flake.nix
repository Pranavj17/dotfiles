{
  description = "Pranav's dotfiles — Home Manager + nix-darwin (Phases 1-2)";

  inputs = {
    nixpkgs.url      = "github:NixOS/nixpkgs/nixpkgs-unstable";
    home-manager = {
      url            = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-darwin = {
      url            = "github:LnL7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, home-manager, nix-darwin, ... }:
    let
      system = "aarch64-darwin";
      pkgs   = import nixpkgs { inherit system; };
    in {
      homeConfigurations."pranav.j" = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        modules = [ ./home/default.nix ];
      };

      darwinConfigurations."SB-111" = nix-darwin.lib.darwinSystem {
        inherit system;
        modules = [ ./system/default.nix ];
      };
    };
}
