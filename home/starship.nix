{ ... }: {
  programs.starship = {
    enable = true;

    # Two-line prompt: info line, then a clean input character.
    settings = {
      format = ''
        $directory\
        $git_branch\
        $git_status\
        $nix_shell\
        ''${custom.elixir}\
        $ruby\
        $nodejs\
        $python\
        $cmd_duration\
        $line_break\
        $character'';

      add_newline     = true;
      command_timeout = 2000;

      character = {
        success_symbol = "[❯](bold green)";
        error_symbol   = "[❯](bold red)";
        vimcmd_symbol  = "[❮](bold yellow)";
      };

      directory = {
        style             = "bold cyan";
        truncation_length = 3;
        truncate_to_repo  = true;
        read_only         = " 󰌾";
      };

      git_branch = {
        symbol = " ";
        style  = "bold purple";
      };

      git_status = {
        style      = "bold yellow";
        ahead      = "⇡\${count}";
        behind     = "⇣\${count}";
        diverged   = "⇕⇡\${ahead_count}⇣\${behind_count}";
        conflicted = "=";
        untracked  = "?\${count}";
        modified   = "!\${count}";
        staged     = "+\${count}";
        stashed    = "≡";
        renamed    = "»\${count}";
        deleted    = "✘\${count}";
      };

      nix_shell = {
        symbol = " ";
        style  = "bold blue";
        format = ''via [$symbol$state( \($name\))]($style) '';
      };

      # Starship's built-in elixir module pays ~420ms BEAM cold-start per redraw
      # inside a mix project. Disable it and use [custom.elixir] (below) routed
      # through `elixir-version-cached`.
      elixir.disabled = true;

      custom.elixir = {
        description  = "Elixir version (cached) — only inside mix projects";
        detect_files = [ "mix.exs" ];
        command      = "$HOME/.local/bin/elixir-version-cached";
        symbol       = " ";
        style        = "bold magenta";
        format       = ''via [$symbol$output ]($style)'';
        shell        = [ "bash" "--noprofile" "--norc" ];
      };

      ruby = {
        symbol = " ";
        style  = "bold red";
        format = ''via [$symbol($version )]($style)'';
      };

      nodejs = {
        symbol = " ";
        style  = "bold green";
        format = ''via [$symbol($version )]($style)'';
      };

      python = {
        symbol = " ";
        style  = "bold yellow";
        format = ''via [$symbol($version )]($style)'';
      };

      cmd_duration = {
        min_time = 2000;
        style    = "bold yellow";
        format   = ''took [$duration]($style) '';
      };
    };
  };
}
