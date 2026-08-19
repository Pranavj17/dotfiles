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
      pkgs   = import nixpkgs {
        inherit system;
        config = {
          allowUnfree = true;  # required for terraform (BSL-1.1)
          permittedInsecurePackages = [
            "nodejs-20.20.2"       # nodejs_20 is EOL but kept for compatibility
            "nodejs-slim-20.20.2"  # slim variant required by yarn
          ];
        };
      };
    in {
      homeConfigurations."pranav" = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        modules = [ ./home/default.nix ];
      };

      darwinConfigurations."SB-111" = nix-darwin.lib.darwinSystem {
        inherit system;
        modules = [
          home-manager.darwinModules.home-manager
          ./system/default.nix
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.backupFileExtension = "home-manager-backup";
            home-manager.users.pranav = {
              imports = [ ./home/default.nix ];
            };
          }
        ];
      };
    };
}
