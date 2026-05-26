{ ... }: {
  home.file = {
    ".local/bin/har-extract"            = { source = ../files/bin/har-extract;             executable = true; };
    ".local/bin/claude-export-split"    = { source = ../files/bin/claude-export-split;     executable = true; };
    ".local/bin/elixir-version-cached"  = { source = ../files/bin/elixir-version-cached;   executable = true; };
    ".config/shell-tests/secret.sh"     = { source = ../files/shell-tests/secret.sh;       executable = true; };
    ".config/shell-tests/run.sh"        = { source = ../files/shell-tests/run.sh;          executable = true; };
  };
}
