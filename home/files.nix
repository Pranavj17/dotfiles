{ config, pkgs, ... }: {
  home.file = {
    ".local/bin/har-extract"            = { source = ../files/bin/har-extract;             executable = true; };
    ".local/bin/elixir-version-cached"  = { source = ../files/bin/elixir-version-cached;   executable = true; };
    ".config/shell-tests/secret.sh"     = { source = ../files/shell-tests/secret.sh;       executable = true; };
    ".config/shell-tests/run.sh"        = { source = ../files/shell-tests/run.sh;          executable = true; };
    ".config/alacritty/alacritty.toml" .source = ../files/alacritty/alacritty.toml;

    # nixpkgs alacritty ships a real .app under $out/Applications. Without
    # this symlink Finder and Spotlight cannot launch it.
    "Applications/Alacritty.app" = {
      source = "${pkgs.alacritty}/Applications/Alacritty.app";
    };
    # Same pattern as Alacritty: the package's .app is not on PATH, so Finder
    # and Spotlight only see it through this symlink.
    "Applications/Maccy.app" = {
      source = "${pkgs.maccy}/Applications/Maccy.app";
    };
  };
}
