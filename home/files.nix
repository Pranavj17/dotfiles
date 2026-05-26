{ ... }: {
  home.file = {
    ".local/bin/har-extract"            = { source = ../files/bin/har-extract;             executable = true; };
    ".local/bin/claude-export-split"    = { source = ../files/bin/claude-export-split;     executable = true; };
    ".local/bin/elixir-version-cached"  = { source = ../files/bin/elixir-version-cached;   executable = true; };
    ".config/shell-tests/secret.sh"     = { source = ../files/shell-tests/secret.sh;       executable = true; };
    ".config/shell-tests/run.sh"        = { source = ../files/shell-tests/run.sh;          executable = true; };
    ".config/starship.toml"             .source = ../files/starship/starship.toml;
    ".config/alacritty/alacritty.toml" .source = ../files/alacritty/alacritty.toml;
    ".claude/settings.json"                         .source = ../files/claude/settings.json;
    ".claude/keybindings.json"                      .source = ../files/claude/keybindings.json;
    ".claude/statusline-command.sh"                 = { source = ../files/claude/statusline-command.sh;   executable = true; };
    ".claude/statusline/probe-mini.sh"              = { source = ../files/claude/statusline/probe-mini.sh;     executable = true; };
    ".claude/statusline/probe-import.sh"            = { source = ../files/claude/statusline/probe-import.sh;   executable = true; };
    ".claude/statusline/probe-triage.sh"            = { source = ../files/claude/statusline/probe-triage.sh;   executable = true; };
    ".claude/statusline/gen-greeter.sh"             = { source = ../files/claude/statusline/gen-greeter.sh;    executable = true; };
    ".claude/statusline/gen-slot.sh"                = { source = ../files/claude/statusline/gen-slot.sh;       executable = true; };
    ".claude/statusline/test.sh"                    = { source = ../files/claude/statusline/test.sh;           executable = true; };
  };
}
