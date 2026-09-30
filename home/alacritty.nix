{ ... }: {
  # Home Manager's module, not a bare home.packages entry. The module links
  # alacritty's terminfo output into the profile, which is what makes
  # TERM=alacritty resolvable. The package alone does not.
  programs.alacritty = {
    enable = true;
    # Config is the repo file symlinked by home/files.nix. Empty settings
    # stops this module from writing a second alacritty.toml.
    settings = { };
  };
}
