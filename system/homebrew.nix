{ ... }: {
  # Declarative brew bundle. nix-darwin will `brew bundle` from this list on
  # every `darwin-rebuild switch`. Brew itself must be installed already
  # (this module does NOT install brew; install via /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)").
  #
  # Casks are GUI apps — code lives in /Applications/. Adding to this list
  # installs on next `switch`; removing uninstalls (cleanup = "uninstall"
  # below).
  homebrew = {
    enable = true;

    # zap = remove dotfiles too; uninstall = remove app + receipt; none = leave.
    onActivation = {
      autoUpdate = false;   # Don't surprise-update on every switch.
      upgrade    = false;   # Same — explicit `brew upgrade` only.
      cleanup    = "uninstall";   # Apps removed from this list get uninstalled.
    };

    taps = [
      # No taps needed for the current cask list.
    ];

    brews = [
      # CLI tools — none in Phase 2; we prefer Nix-managed equivalents.
    ];

    casks = [
      "alacritty"
      "claude"
      "google-chrome"
      "tunnelblick"
      # Future additions (per spec): "cursor", "docker"  — currently NOT installed
      # on this machine. Uncomment + switch to install.
    ];

    masApps = {
      # Mac App Store apps — none for now.
    };
  };
}
