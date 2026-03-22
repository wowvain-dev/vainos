# lib/mkHost.nix -- Host builder with auto-import, option namespaces, and dynamic module discovery.
# machineConfig is eliminated -- systemSettings/userSettings is THE single API.
#
# Auto-import sources:
#   1. modules/system/* -- system modules (via autoImport, toggled by systemSettings.*.enable)
#   2. modules/user/*   -- user modules (via autoImport, toggled by userSettings.*.enable)
#   3. hosts/{name}/*.nix -- host-specific .nix files (except default.nix + hardware-configuration.nix)
#   4. hosts/{name}/default.nix -- host data file (systemSettings/userSettings assignments only)
#   5. hardware-configuration.nix -- gitignored, loaded via impure absolute path (passed as hwConfigModule)
#   6. local/{name}.nix -- machine-specific config, gitignored (passed as localConfigModule)
{ inputs, ... }:
let
  autoImport = import ./autoImport.nix;
in
name: { system, modules ? [], hwConfigModule ? null, localConfigModule ? null }:
let
  systemModules = autoImport ../modules/system;
  userModules = autoImport ../modules/user;

  # Auto-import .nix files from the host directory.
  # Excludes default.nix (data file, imported separately) and hardware-configuration.nix (gitignored, loaded via impure path).
  hostDir = ../hosts/${name};
  hostDirEntries = builtins.readDir hostDir;
  hostDirModules = builtins.filter (p: p != null) (
    builtins.map (fileName:
      if builtins.match ".*\\.nix" fileName != null
         && fileName != "default.nix"
         && fileName != "hardware-configuration.nix"
      then hostDir + "/${fileName}"
      else null
    ) (builtins.attrNames hostDirEntries)
  );

  hwConfig = if hwConfigModule != null then [ hwConfigModule ] else [];
  localMod = if localConfigModule != null then [ localConfigModule ] else [];
in
inputs.nixpkgs.lib.nixosSystem {
  inherit system;
  specialArgs = { inherit inputs; hostname = name; };
  modules = [
    ./options.nix
    ../hosts/${name}
  ] ++ hostDirModules ++ hwConfig ++ localMod ++ [
    # mkHost-managed NixOS settings: hostName is always the directory name,
    # stateVersion is read from systemSettings.stateVersion.
    ({ config, ... }: {
      networking.hostName = name;
      system.stateVersion = config.systemSettings.stateVersion;
    })
    inputs.sops-nix.nixosModules.sops
    inputs.home-manager.nixosModules.home-manager
    {
      home-manager.useGlobalPkgs = true;
      home-manager.useUserPackages = true;
      home-manager.extraSpecialArgs = { inherit inputs; hostname = name; };
      home-manager.users.wowvain = {
        home.stateVersion = "25.11";
        programs.home-manager.enable = true;
      };
    }
    inputs.stylix.nixosModules.stylix
  ] ++ systemModules ++ userModules ++ modules;
}
