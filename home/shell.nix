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
      source ${../files/zsh/functions.zsh}
      source ${../files/zsh/dwim.zsh}
    '';
  };

  # Headroom (local proxy defaults).
  #
  # ~/.zshrc is HM-managed (symlink into /nix/store). Never let Headroom write it:
  #   headroom install apply --scope user   # → EACCES on nix store
  # Use instead:
  #   headroom install apply --scope provider
  #
  # These vars configure Headroom CLI / wrap defaults (latency-first + Grok
  # OpenAI-compat upstream). Do NOT set ANTHROPIC_BASE_URL / OPENAI_BASE_URL
  # globally here — that would force every Claude/OpenAI CLI through the proxy.
  # Grok Build routes via ~/.grok/config.toml model base_url instead.
  home.sessionVariables = {
    HEADROOM_PORT = "8787";
    HEADROOM_HOST = "127.0.0.1";
    HEADROOM_MODE = "cache";
    HEADROOM_TELEMETRY = "off";
    HEADROOM_DISABLE_KOMPRESS_OPENAI = "1";
    HEADROOM_PROTECT_RECENT = "6";
    HEADROOM_MIN_TOKENS = "2000";
    # Fail-open on compression timeout (default is HTTP 413 fail-closed).
    # Also pinned on ~/.headroom/deploy/default/manifest.json via `hr-failopen`.
    HEADROOM_WS_FAIL_OPEN_ON_COMPRESSION_FAILURE = "1";
    HEADROOM_COMPRESSION_TIMEOUT_SECONDS = "60";
    OPENAI_TARGET_API_URL = "https://api.x.ai";
  };

  # direnv with the zsh hook auto-injected by HM. Replaces `eval "$(direnv hook zsh)"`.
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };
}
