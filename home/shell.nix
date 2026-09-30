{ pkgs, ... }: {
  programs.zsh = {
    enable = true;

    # zsh-autosuggestions — fish-style gray inline hints from history (>/End to accept).
    autosuggestion.enable = true;

    # zsh-syntax-highlighting — live command coloring. HM sources it last in the
    # generated .zshrc, which is the correct order (it hooks zle widgets defined before it).
    syntaxHighlighting.enable = true;

    # Everything else — PATH, aliases, secret function, metabase helpers, rotate helpers,
    # PROMPT_SUBST belt-and-braces — lives in functions.zsh so the shell stays as shell.
    # Source the flake inputs from the Nix store so the checkout may live anywhere.
    initExtra = ''
      # autojump's `j` function. The package does not put this on PATH.
      source ${pkgs.autojump}/etc/profile.d/autojump.sh
      source ${../files/zsh/functions.zsh}
      source ${../files/zsh/dwim.zsh}
    '';
  };

  # direnv with the zsh hook auto-injected by HM, pinned to the Nix store
  # binary. Do not also `eval "$(direnv hook zsh)"` in zshrc: that resolves
  # via PATH and would pick up a Homebrew direnv ahead of this one.
  #
  # direnv 2.37 ignores DIRENV_LOG_FORMAT, so the quiet config has to live in
  # direnv.toml. log_filter is an allow-list; real errors still print.
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
    config.global = {
      hide_env_diff = true;
      warn_timeout = "60s";
      # nix-direnv needs bash >= 4.4. macOS /bin/bash is 3.2.
      bash_path = "${pkgs.bash}/bin/bash";
      log_filter = "blocked|taking a while|failed|out of date|not allowed|error";
    };
  };
}
