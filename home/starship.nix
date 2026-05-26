{ lib, ... }: {
  # programs.starship.enable injects `eval "$(starship init zsh)"` into the
  # HM-generated .zshrc. We want that bit.
  #
  # BUT — when `programs.starship.settings.format` is set, HM's starship
  # module runs a "prettifier" that splits the format string at variable
  # boundaries and inserts \<NL> line continuations between them. Some
  # starship versions reject that ("expected escaped_char"). Bypass the
  # prettifier entirely by providing the config file directly via
  # xdg.configFile + lib.mkForce — wins over HM's auto-written one. The
  # spec already adopts this approach for alacritty.toml when TOML
  # serialization rules bite; same pattern here for starship.toml.
  programs.starship.enable = true;

  xdg.configFile."starship.toml".source =
    lib.mkForce ../files/starship/starship.toml;
}
