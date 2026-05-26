{ pkgs, ... }: {
  # System-level packages. Phase 2 keeps this near-empty — user-scoped pkgs
  # live in home/packages.nix. Add things here only when they MUST be on the
  # system PATH for non-login contexts (root cron, system scripts), or when
  # nix-darwin/launchd configs reference them and we want them /run/current-system/sw/bin.
  environment.systemPackages = with pkgs; [
    # Intentionally empty — see home/packages.nix for user pkgs.
  ];
}
