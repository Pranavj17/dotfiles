{ config, ... }: {
  home.file = {
    ".local/bin/har-extract"            = { source = ../files/bin/har-extract;             executable = true; };
    ".local/bin/claude-export-split"    = { source = ../files/bin/claude-export-split;     executable = true; };
    ".local/bin/elixir-version-cached"  = { source = ../files/bin/elixir-version-cached;   executable = true; };
    ".config/shell-tests/secret.sh"     = { source = ../files/shell-tests/secret.sh;       executable = true; };
    ".config/shell-tests/run.sh"        = { source = ../files/shell-tests/run.sh;          executable = true; };
    ".config/alacritty/alacritty.toml" .source = ../files/alacritty/alacritty.toml;
    ".claude/settings.json"                         .source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/dotfiles/files/claude/settings.json";
    ".claude/keybindings.json"                      .source = ../files/claude/keybindings.json;
    ".claude/statusline-command.sh"                 = { source = ../files/claude/statusline-command.sh;   executable = true; };
    ".claude/hooks/helixa-session-greeting.sh"      = { source = ../files/claude/hooks/helixa-session-greeting.sh; executable = true; };
    ".claude/statusline/probe-mini.sh"              = { source = ../files/claude/statusline/probe-mini.sh;     executable = true; };
    ".claude/statusline/probe-import.sh"            = { source = ../files/claude/statusline/probe-import.sh;   executable = true; };
    ".claude/statusline/probe-triage.sh"            = { source = ../files/claude/statusline/probe-triage.sh;   executable = true; };
    ".claude/statusline/gen-greeter.sh"             = { source = ../files/claude/statusline/gen-greeter.sh;    executable = true; };
    ".claude/statusline/gen-slot.sh"                = { source = ../files/claude/statusline/gen-slot.sh;       executable = true; };
    ".claude/statusline/test.sh"                    = { source = ../files/claude/statusline/test.sh;           executable = true; };

    ".claude/projects/-Users-pranav-j-Documents-memory/memory/MEMORY.md".source                                = ../files/claude/projects-memory/MEMORY.md;
    ".claude/projects/-Users-pranav-j-Documents-memory/memory/dev-env-nix-toolchain.md".source                = ../files/claude/projects-memory/dev-env-nix-toolchain.md;
    ".claude/projects/-Users-pranav-j-Documents-memory/memory/milky-way-repo.md".source                       = ../files/claude/projects-memory/milky-way-repo.md;
    ".claude/projects/-Users-pranav-j-Documents-memory/memory/nix-npx-broken-prefix.md".source                = ../files/claude/projects-memory/nix-npx-broken-prefix.md;
    ".claude/projects/-Users-pranav-j-Documents-memory/memory/apps-repo-clean-build.md".source                = ../files/claude/projects-memory/apps-repo-clean-build.md;
    ".claude/projects/-Users-pranav-j-Documents-memory/memory/kubelogin-port-8000-chroma-collision.md".source = ../files/claude/projects-memory/kubelogin-port-8000-chroma-collision.md;
    ".claude/projects/-Users-pranav-j-Documents-memory/memory/alacritty-toml-escapes.md".source               = ../files/claude/projects-memory/alacritty-toml-escapes.md;
    ".claude/projects/-Users-pranav-j-Documents-memory/memory/claude-bot-plugin-bun.md".source                = ../files/claude/projects-memory/claude-bot-plugin-bun.md;
    ".claude/projects/-Users-pranav-j-Documents-memory/memory/scripbox-vpn-endpoint.md".source                = ../files/claude/projects-memory/scripbox-vpn-endpoint.md;
    ".claude/projects/-Users-pranav-j-Documents-memory/memory/metabase-lead-id-lookup.md".source              = ../files/claude/projects-memory/metabase-lead-id-lookup.md;
    ".claude/projects/-Users-pranav-j-Documents-memory/memory/nested-claude-headless-sandbox.md".source       = ../files/claude/projects-memory/nested-claude-headless-sandbox.md;
    ".claude/projects/-Users-pranav-j-Documents-memory/memory/secrets-keychain-preference.md".source          = ../files/claude/projects-memory/secrets-keychain-preference.md;

    ".claude-bot/CLAUDE.md".source = ../files/claude-bot/CLAUDE.md;
    ".claude-bot/.mcp.json".source = ../files/claude-bot/.mcp.json;
    ".claude-bot/memory/echo-personality.md".source       = ../files/claude-bot/memory/echo-personality.md;
    ".claude-bot/memory/pranav-profile.md".source         = ../files/claude-bot/memory/pranav-profile.md;
    ".claude-bot/memory/pranav-claude-insights.md".source = ../files/claude-bot/memory/pranav-claude-insights.md;
    ".claude-bot/memory/alacritty-keybindings.md".source  = ../files/claude-bot/memory/alacritty-keybindings.md;
    ".claude-bot/memory/nix-setup.md".source              = ../files/claude-bot/memory/nix-setup.md;
    ".claude-bot/memory/scripbox-repositories.md".source  = ../files/claude-bot/memory/scripbox-repositories.md;
    ".claude-bot/memory/vpn-setup.md".source              = ../files/claude-bot/memory/vpn-setup.md;
    ".claude-bot/memory/secret-rotation-helpers.md".source = ../files/claude-bot/memory/secret-rotation-helpers.md;

  };
}
