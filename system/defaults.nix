{ ... }: {
  # macOS UI / dev defaults — applied by `darwin-rebuild switch`.
  # All settings here are reversible: removing a line restores macOS's default
  # at the next switch.
  system.defaults = {
    NSGlobalDomain = {
      # Key repeat tuned for fast cursor navigation.
      InitialKeyRepeat = 10;   # delay before repeat (15 = stock fastest)
      KeyRepeat        = 1;    # repeat rate (2 = stock fastest)

      # Show file extensions in Finder.
      AppleShowAllExtensions = true;

      # Don't auto-correct or smart-substitute in dev work.
      NSAutomaticSpellingCorrectionEnabled    = false;
      NSAutomaticCapitalizationEnabled        = false;
      NSAutomaticDashSubstitutionEnabled      = false;
      NSAutomaticPeriodSubstitutionEnabled    = false;
      NSAutomaticQuoteSubstitutionEnabled     = false;

      # Save panel + print panel default to expanded.
      NSNavPanelExpandedStateForSaveMode      = true;
      PMPrintingExpandedStateForPrint         = true;
    };

    dock = {
      autohide       = true;
      orientation    = "bottom";
      tilesize       = 48;
      show-recents   = false;
      mru-spaces     = false;
      minimize-to-application = true;
    };

    finder = {
      AppleShowAllExtensions   = true;
      AppleShowAllFiles        = true;
      FXEnableExtensionChangeWarning = false;
      FXPreferredViewStyle     = "Nlsv";   # list view
      ShowPathbar              = true;
      ShowStatusBar            = true;
      _FXShowPosixPathInTitle  = true;
    };

    screencapture = {
      location = "~/Pictures/Screenshots";
      type     = "png";
      disable-shadow = true;
    };

    trackpad = {
      Clicking                  = true;   # tap to click
      TrackpadRightClick        = true;
    };
  };

  # Touch ID for sudo. Reversible (set to false to revert).
  security.pam.services.sudo_local.touchIdAuth = true;
}
