# Server containers module — RETIRED (Phase 10)
# Container definitions moved to per-site modules under modules/system/server/sites/
# sops.age.sshKeyPaths moved to modules/system/server/deploy/default.nix
# This module is kept as an empty shell until the next cleanup pass.
{ config, lib, ... }:

let
  cfg = config.systemSettings.server.containers;
in
{
  options.systemSettings.server.containers = {
    enable = lib.mkEnableOption "OCI containers (RETIRED -- use per-site modules)";
  };

  # No config -- module is retired.
  # Keeping the option prevents evaluation errors if still referenced.
}
