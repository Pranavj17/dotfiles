{ pkgs, ... }: {
  # User-scoped launchd agent for the Echo bot (claude-bot plugin daemon).
  # Replaces the previously hand-managed
  # ~/Library/LaunchAgents/com.claude-bot.daemon.plist — that plist is retired
  # in P2.8 once this one is verified running.
  launchd.user.agents.claude-bot = {
    serviceConfig = {
      Label = "com.claude-bot.daemon";

      ProgramArguments = [
        "/Users/pranav.j/.nix-profile/bin/bun"
        "run"
        "/Users/pranav.j/.claude/plugins/cache/claude-community/claude-bot/0.1.0/daemon/index.ts"
      ];

      EnvironmentVariables = {
        # Minimal PATH — covers HM bun + brew + macOS. The previous plist
        # baked in every /nix/store path the shell had at plist-generation
        # time; that was fragile (store paths change on every nixpkgs bump).
        PATH = "/Users/pranav.j/.nix-profile/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin";
      };

      RunAtLoad   = true;
      KeepAlive   = true;

      WorkingDirectory = "/Users/pranav.j/.claude-bot";
      StandardOutPath  = "/Users/pranav.j/.claude-bot/logs/claude-bot.stdout.log";
      StandardErrorPath = "/Users/pranav.j/.claude-bot/logs/claude-bot.stderr.log";
    };
  };
}
