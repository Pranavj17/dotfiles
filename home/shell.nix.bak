{ pkgs, ... }: {
  programs.zsh = {
    enable = true;

    # zsh-autosuggestions — fish-style gray inline hints from history (→/End to accept).
    autosuggestion.enable = true;

    # zsh-syntax-highlighting — live command coloring. HM sources it last in the
    # generated .zshrc, which is the correct order (it hooks zle widgets defined before it).
    syntaxHighlighting.enable = true;

    # Everything else — PATH, aliases, secret function, metabase helpers, rotate helpers,
    # PROMPT_SUBST belt-and-braces — lives in functions.zsh so the shell stays as shell.
    # readFile preserves bytes exactly (no Nix-string $ escaping needed).
    # dwim.zsh appends the local-LLM command corrector (preexec/precmd + `dwim`).
    initExtra = builtins.readFile ../files/zsh/functions.zsh
      + "\n" + builtins.readFile ../files/zsh/dwim.zsh;
  };

  # direnv with the zsh hook auto-injected by HM. Replaces `eval "$(direnv hook zsh)"`.
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };
}
