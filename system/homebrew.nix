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
    #
    # IMPORTANT: cleanup = "none". We declare the casks we WANT installed but
    # don't auto-uninstall anything else the user has via brew. An earlier
    # "uninstall" setting purged Maccy (and possibly others); switching to
    # "none" prevents that class of error. Promote to "uninstall" only after
    # you're CERTAIN the cask list is exhaustive of every brew cask you use.
    onActivation = {
      autoUpdate = false;   # Don't surprise-update on every switch.
      upgrade    = false;   # Same — explicit `brew upgrade` only.
      cleanup    = "none";  # NEVER auto-uninstall (was "uninstall"; bit us).
    };

    taps = [
      # No taps needed for the current cask list.
    ];

    brews = [
      # CLI tools we want managed by brew (not Nix). Reasons to be here:
      #   - macOS-specific tooling (autojump's profile.d hook expects /opt/homebrew)
      #   - apps with native services (colima, ollama) that brew installs cleanly
      #   - tools where the brew version is the canonical/blessed one (docker CLI)
      # All of these were lost in the earlier brew bundle cleanup="uninstall"
      # incident; declared here so they survive every future `darwin-rebuild`.
      "autojump"             # referenced by ~/.zshrc; `j <partial-dir>` jump
      "colima"               # docker daemon backend (lightweight VM)
      "docker"               # docker CLI
      "docker-compose"       # compose plugin
      "ffmpeg"               # video/audio processing
      "gh"                   # GitHub CLI
      "ghostscript"          # PDF/PS toolchain
      "helm"                 # k8s package manager
      "imagemagick"          # image processing
      "k9s"                  # k8s TUI
      "kubernetes-cli"       # kubectl
      "ollama"               # local LLM runner
      "pandoc"               # universal doc converter
      "poppler"              # PDF toolkit (pdftotext, pdfimages)
    ];

    casks = [
      "alacritty"
      "claude"
      "google-chrome"
      "maccy"                # clipboard manager; restored after accidental cleanup
      "tunnelblick"
      # NOTE: Tailscale.app exists in /Applications but was installed via DMG,
      # not brew cask — keep it that way (avoids re-install on next switch).
      # Future additions (per spec): "cursor", "docker"  — currently NOT installed
      # on this machine. Uncomment + switch to install.
    ];

    masApps = {
      # Mac App Store apps — none for now.
    };
  };
}
